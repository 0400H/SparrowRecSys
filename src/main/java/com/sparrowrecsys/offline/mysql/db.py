import os
import argparse
from mysql import MySQL

def import_movieLens(args, dir_path):
    db = MySQL(args.host, args.port, args.user, args.password)
    print(db.show_databases())

    try:
        db.drop_database('sparrow_recsys')
    except:
        pass
    db.create_use_utf8_db('sparrow_recsys')

    db.create_table('movies', """
        `movieId` BIGINT(20) NOT NULL,
        `title` VARCHAR(100) NULL,
        `genres` VARCHAR(200) NULL,
        PRIMARY KEY (`movieId`)
    """)
    db.create_table('ratings', """
        `userId` BIGINT(20) NOT NULL,
        `movieId` BIGINT(20) NOT NULL,
        `rating` FLOAT NULL,
        `timestamp` BIGINT(20) NULL,
        PRIMARY KEY (`userId`, `movieId`)
    """)
    print(db.show_tables())

    db.set_global_local_infile(True)
    db.load_csv_into_table('movies', dir_path+'/movies.csv')
    db.load_csv_into_table('ratings', dir_path+'/ratings.csv')

    db.close()

    db.open()
    db.use_database('sparrow_recsys')

    print(db.show_table_data('movies')[:100])
    print(db.show_table_data('ratings')[:100])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-H', '--host', type=str, default='127.0.0.1', help='mysql server address')
    parser.add_argument('-P', '--port', type=int, default=3306, help='mysql port')
    parser.add_argument('-u', '--user', type=str, default='root', help='user')
    parser.add_argument('-p', '--password', type=str, default=None, help='password')
    args = parser.parse_args()

    workdir = os.getenv('WORK_DIR')
    import_movieLens(args, workdir+"/src/main/resources/webroot/sampledata")
