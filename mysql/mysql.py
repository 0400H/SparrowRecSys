import pymysql

class MySQL(object):
    def __init__(self, host, port, user, password):
        self.host = host
        self.port = port
        self.user = user
        self.password = password
        print(self.host)
        self.open()

    def open(self):
        self.connection = pymysql.connect(
                                host = self.host,
                                port = self.port,
                                user = self.user,
                                password = self.password,
                                local_infile=True)
        self.cursor = self.connection.cursor()

    def commit(self):
        self.connection.commit()

    def close(self):
        if self.connection:
            self.commit()
            self.connection.close()
        if self.cursor:
            self.cursor.close()

    def show_databases(self):
        self.cursor.execute('show databases;')
        return self.cursor.fetchall()

    def create_database(self, db_name):
        return self.cursor.execute('create database %s' % (db_name))

    def drop_database(self, db_name):
        return self.cursor.execute('drop database %s' % (db_name))

    def use_database(self, db_name):
        return self.cursor.execute('use %s;' % (db_name))

    def create_use_utf8_db(self, db_name):
        self.create_database(db_name)
        self.use_database(db_name)
        return self.cursor.execute('set names utf8;')

    def show_tables(self):
        self.cursor.execute('show tables;')
        return self.cursor.fetchall()

    def show_db_tables(self, db_name):
        self.cursor.execute('show tables;')
        return self.cursor.fetchall()

    def create_table(self, table_name, table_content):
        return self.cursor.execute('create table %s (%s);' % (table_name, table_content))

    def show_table_columns(self, table_name):
        self.cursor.execute('show columns from %s;' % (table_name))
        return self.cursor.fetchall()

    def show_table_data(self, table_name):
        self.cursor.execute('select * from %s;' % (table_name))
        return self.cursor.fetchall()

    def set_global_local_infile(self, status=True):
        if status == True:
            status = 'true'
        else:
            status = 'false'
        self.cursor.execute('set global local_infile=%s;' % (status))
        return self.cursor.fetchall()

    def load_csv_into_table(self, table_name, csv_path):
        cmd = """load data local infile "%s" into table %s fields terminated by ',' optionally enclosed by '"' escaped by '"';""" % (csv_path, table_name)
        self.cursor.execute(cmd)
        self.commit()

    def load_csv_1line_into_table(self, table_name, csv_path):
        cmd = """load data local infile "%s" into table %s fields terminated by ',' optionally enclosed by '"' escaped by '"' lines terminated by '\r\n';""" % (csv_path, table_name)
        self.cursor.execute(cmd)
        self.commit()

    def __exit__(self):
        self.close()
