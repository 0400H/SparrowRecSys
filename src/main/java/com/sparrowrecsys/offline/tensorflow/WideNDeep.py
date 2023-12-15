
import os
import subprocess
import shutil
from time import localtime, strftime
import redis
import json
from tqdm import tqdm

import tensorflow as tf


intra_threads = int(os.getenv('INTER_OP_PARALLELISM_THREADS', default=16))
print('intra_threads:%d' % (intra_threads))

MODEL_TYPE = "widendeep"

HDFS_SERVER = "hdfs://sparrow-recsys:8020"
HDFS_PATH_SAMPLE_DATA = HDFS_SERVER + "/sparrow_recsys/sampledata"
HDFS_PATH_MODEL_DATA = HDFS_SERVER + "/sparrow_recsys/modeldata"
HDFS_PATH_TARGET_MODEL_DATA = f"{HDFS_PATH_MODEL_DATA}/{MODEL_TYPE}"

REDIS_SERVER="sparrow-recsys"
REDIS_PORT=6379
REDIS_PASSWD="123456"
REDIS_KEY_VERSION_MODEL_WIDE_DEEP = "sparrow_recsys:version:model_wd"

working_dir = '/tmp/my_working_dir'
log_dir = os.path.join(working_dir, 'log')
ckpt_filepath = os.path.join(working_dir, 'ckpt')
backup_dir = os.path.join(working_dir, 'backup')

# download sampling data from HDFS
tmp_sample_dir = "/tmp/sample/" + MODEL_TYPE
tmp_model_dir = "/tmp/model/" + MODEL_TYPE
train_data = f"{tmp_sample_dir}/trainingSamples/*/part-*.csv"
test_data = f"{tmp_sample_dir}/testSamples/*/part-*.csv"

def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)

# load sample as tf dataset
def get_dataset(file_path):
    global batch_size
    dataset = tf.data.experimental.make_csv_dataset(
        file_path,
        batch_size=batch_size,
        label_name='label',
        na_value="0",
        num_epochs=1,
        ignore_errors=True)
    return dataset

def dataset_fn(input_context):
    train_dataset = get_dataset(train_data)
    dataset = train_dataset
    dataset = dataset.repeat().shard(
        input_context.num_input_pipelines,
        input_context.input_pipeline_id)
    return dataset

mkdir(tmp_model_dir)
mkdir(tmp_sample_dir)
shutil.rmtree(tmp_sample_dir)

subprocess.Popen(["hdfs", "dfs", "-get", HDFS_PATH_SAMPLE_DATA, tmp_sample_dir], stdout=subprocess.PIPE).communicate()

# genre features vocabulary
genre_vocab = ['Film-Noir', 'Action', 'Adventure', 'Horror', 'Romance', 'War', 'Comedy', 'Western', 'Documentary',
               'Sci-Fi', 'Drama', 'Thriller',
               'Crime', 'Fantasy', 'Animation', 'IMAX', 'Mystery', 'Children', 'Musical']

GENRE_FEATURES = {
    'userGenre1': genre_vocab,
    'userGenre2': genre_vocab,
    'userGenre3': genre_vocab,
    'userGenre4': genre_vocab,
    'userGenre5': genre_vocab,
    'movieGenre1': genre_vocab,
    'movieGenre2': genre_vocab,
    'movieGenre3': genre_vocab
}

# all categorical features
categorical_columns = []
for feature, vocab in tqdm(GENRE_FEATURES.items()):
    cat_col = tf.feature_column.categorical_column_with_vocabulary_list(
        key=feature, vocabulary_list=vocab)
    emb_col = tf.feature_column.embedding_column(cat_col, 10)
    categorical_columns.append(emb_col)

# movie id embedding feature
movie_col = tf.feature_column.categorical_column_with_identity(key='movieId', num_buckets=2001)
movie_emb_col = tf.feature_column.embedding_column(movie_col, 10)
categorical_columns.append(movie_emb_col)

# user id embedding feature
user_col = tf.feature_column.categorical_column_with_identity(key='userId', num_buckets=30001)
user_emb_col = tf.feature_column.embedding_column(user_col, 10)
categorical_columns.append(user_emb_col)

# all numerical features
numerical_columns = [tf.feature_column.numeric_column('releaseYear'),
                     tf.feature_column.numeric_column('movieRatingCount'),
                     tf.feature_column.numeric_column('movieAvgRating'),
                     tf.feature_column.numeric_column('movieRatingStddev'),
                     tf.feature_column.numeric_column('userRatingCount'),
                     tf.feature_column.numeric_column('userAvgRating'),
                     tf.feature_column.numeric_column('userRatingStddev')]

# cross feature between current movie and user historical movie
rated_movie = tf.feature_column.categorical_column_with_identity(key='userRatedMovie1', num_buckets=2001)
crossed_feature = tf.feature_column.indicator_column(tf.feature_column.crossed_column([movie_col, rated_movie], 10000))

# define input for keras model
inputs = {
    'movieAvgRating': tf.keras.layers.Input(name='movieAvgRating', shape=(), dtype='float32'),
    'movieRatingStddev': tf.keras.layers.Input(name='movieRatingStddev', shape=(), dtype='float32'),
    'movieRatingCount': tf.keras.layers.Input(name='movieRatingCount', shape=(), dtype='int32'),
    'userAvgRating': tf.keras.layers.Input(name='userAvgRating', shape=(), dtype='float32'),
    'userRatingStddev': tf.keras.layers.Input(name='userRatingStddev', shape=(), dtype='float32'),
    'userRatingCount': tf.keras.layers.Input(name='userRatingCount', shape=(), dtype='int32'),
    'releaseYear': tf.keras.layers.Input(name='releaseYear', shape=(), dtype='int32'),

    'movieId': tf.keras.layers.Input(name='movieId', shape=(), dtype='int32'),
    'userId': tf.keras.layers.Input(name='userId', shape=(), dtype='int32'),
    'userRatedMovie1': tf.keras.layers.Input(name='userRatedMovie1', shape=(), dtype='int32'),

    'userGenre1': tf.keras.layers.Input(name='userGenre1', shape=(), dtype='string'),
    'userGenre2': tf.keras.layers.Input(name='userGenre2', shape=(), dtype='string'),
    'userGenre3': tf.keras.layers.Input(name='userGenre3', shape=(), dtype='string'),
    'userGenre4': tf.keras.layers.Input(name='userGenre4', shape=(), dtype='string'),
    'userGenre5': tf.keras.layers.Input(name='userGenre5', shape=(), dtype='string'),
    'movieGenre1': tf.keras.layers.Input(name='movieGenre1', shape=(), dtype='string'),
    'movieGenre2': tf.keras.layers.Input(name='movieGenre2', shape=(), dtype='string'),
    'movieGenre3': tf.keras.layers.Input(name='movieGenre3', shape=(), dtype='string'),
}

# train model with parameter servers
num_ps = len(json.loads(os.environ["TF_CONFIG"])['cluster']['ps'])
print(f"parameter server count: {num_ps}")

cluster_resolver = tf.distribute.cluster_resolver.TFConfigClusterResolver()

variable_partitioner = (
    tf.distribute.experimental.partitioners.MinSizePartitioner(
        min_shard_bytes=(256 << 10),
        max_shards=num_ps))

strategy = tf.distribute.experimental.ParameterServerStrategy(
    cluster_resolver,
    variable_partitioner=variable_partitioner)

batch_size = 64
dc = tf.keras.utils.experimental.DatasetCreator(dataset_fn)

with strategy.scope():
    # wide and deep model architecture
    # deep part for all input features
    deep = tf.keras.layers.DenseFeatures(numerical_columns + categorical_columns)(inputs)
    deep = tf.keras.layers.Dense(128, activation='relu')(deep)
    deep = tf.keras.layers.Dense(128, activation='relu')(deep)
    # wide part for cross feature
    wide = tf.keras.layers.DenseFeatures(crossed_feature)(inputs)
    both = tf.keras.layers.concatenate([deep, wide])
    output_layer = tf.keras.layers.Dense(1, activation='sigmoid')(both)

    model = tf.keras.Model(inputs, output_layer)

    # compile the model, set loss function, optimizer and evaluation metrics
    model.compile(
        loss='binary_crossentropy',
        optimizer='adam',
        metrics=['accuracy', tf.keras.metrics.AUC(curve='ROC'), tf.keras.metrics.AUC(curve='PR')])

# train the model
callbacks = [
    tf.keras.callbacks.TensorBoard(log_dir=log_dir),
    tf.keras.callbacks.ModelCheckpoint(filepath=ckpt_filepath),
    tf.keras.callbacks.BackupAndRestore(backup_dir=backup_dir),
]

model.fit(dc, batch_size=batch_size, epochs=5, steps_per_epoch=1000, callbacks=callbacks, workers=intra_threads, use_multiprocessing=True)

model.summary()

# evaluate the model
batch_size=64
test_dataset = get_dataset(test_data)

eval_accuracy = tf.keras.metrics.Accuracy()
for batch_data, labels in tqdm(test_dataset):
    preds = model.predict(batch_data, batch_size=batch_size, workers=intra_threads, use_multiprocessing=True, verbose=0)
    actual_preds = tf.cast(tf.greater(preds, 0.5), tf.int64)
    eval_accuracy.update_state(labels, actual_preds)
print ("Evaluation accuracy: %f" % eval_accuracy.result())

# print some predict results
for pred, goodRating in tqdm(zip(preds, labels)):
    print("Predicted good rating: {:.2%}".format(pred[0]),
          " | Actual rating label: ",
          ("Good Rating" if bool(goodRating) else "Bad Rating"))

# save model
version=strftime("%Y%m%d%H%M%S", localtime())
print(f"Saving model with version: {version}")

tf.keras.models.save_model(
    model,
    f"{tmp_model_dir}/{version}",
    overwrite=True,
    include_optimizer=True,
    save_format=None,
    signatures=None,
    options=None
)

if os.path.exists(f"{tmp_model_dir}/{version}"):
    subprocess.Popen(["hdfs", "dfs", "-rm", "-r", f"{HDFS_PATH_TARGET_MODEL_DATA}/{version}"], stdout=subprocess.PIPE).communicate()
    subprocess.Popen(["hdfs", "dfs", "-mkdir", "-p", f"{HDFS_PATH_TARGET_MODEL_DATA}/"], stdout=subprocess.PIPE).communicate()
    subprocess.Popen(["hdfs", "dfs", "-put", f"{tmp_model_dir}/{version}", f"{HDFS_PATH_TARGET_MODEL_DATA}/"], stdout=subprocess.PIPE).communicate()
    print(f"WideNDeep model data is uploaded to HDFS: {HDFS_PATH_TARGET_MODEL_DATA}/{version}")

    # update model version in redis
    r = redis.Redis(host=REDIS_SERVER, port=REDIS_PORT, password=REDIS_PASSWD)
    r.set(REDIS_KEY_VERSION_MODEL_WIDE_DEEP, version)

