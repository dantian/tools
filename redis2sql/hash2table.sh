#!/bin/bash

set -e

### Define the Redis host
HOST=127.0.0.1

### Define the Redis port
PORT=6379

### Define the prefix of the keys in Redis that will be migrated to a MySql table
KEY_PREFIX='TEST-KEY'

### Define the name of the database table in MySql
DATABASE=RedisKeySqlDB

### Define the name of the table in the MySql database
NEW_TABLE=rediskeys


usage () {
cat <<- EOF
USAGE:
  This script uses keys, their values, and their Time To Live (TTL) data (in seconds) in a Redis database to create a MySql script. 
  The created script will create a MySql database with a table containing the columns (textkey, textval, expiretime). 
  The script will also insert rows in the table, with each row representing a key, its value and TTL data, retrieved from the Redis database.  

  IMPORTANT: Please first check and update (if necessary) values of the variables (HOST, PORT, KEY_PREFIX, DATABASE, NEW_TABLE) in this script. 

  Create the MySql script file addSqlTbl.sql by running the command: $(basename "$0") |tee addSqlTbl.sql 
  Create the MySql table using the script file by running the command: mysql -h MYSQL_HOST -u root -p <addSqlTbl.sql 

EOF
exit 1
}

if [ ${#@} > 0 ]; then
   usage
fi


cat <<EOF
-- MySQL dump 10.13  Distrib 8.0.13, for Linux (i686)
--
-- Host:     Database: ${DATABASE}
-- ------------------------------------------------------
-- Server version	5.6.10

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
 SET NAMES utf8mb4 ;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: ${DATABASE}
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ ${DATABASE} /*!40100 DEFAULT CHARACTER SET utf8 */;

USE ${DATABASE};

--
-- Table structure for table ${NEW_TABLE}
--

DROP TABLE IF EXISTS ${NEW_TABLE};
/*!40101 SET @saved_cs_client     = @@character_set_client */;
 SET character_set_client = utf8mb4 ;
CREATE TABLE ${NEW_TABLE} (
  textkey varchar(255) NOT NULL,
  textval varchar(255) DEFAULT 'Y',
  expiretime TIMESTAMP DEFAULT NULL,
  PRIMARY KEY (textkey),
  UNIQUE KEY textkey_UNIQUE (textkey)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table ${NEW_TABLE}
--

LOCK TABLES ${NEW_TABLE} WRITE;
/*!40000 ALTER TABLE ${NEW_TABLE} DISABLE KEYS */;
EOF




### Get all keys in Redis with the prefix
### Ref. https://redis.io/commands/KEYS

KEYS=`redis-cli -h $HOST -p $PORT keys ${KEY_PREFIX}*|cut -d")" -f2`

for k in $KEYS; do
   #### Get value for key: $k
   #### Ref. https://redis.io/commands/get
   #### Ref. https://redis.io/commands/TTL

   v=`redis-cli -h $HOST -p $PORT get $k`
   kttl=`redis-cli -h $HOST -p $PORT ttl $k`
   now=`date +"%F %T"`
   #### Create SQL insert stetement to insert a row representing the key and it's value and ttl in the mysql table
   echo "INSERT INTO stopreg VALUES ('$k','$v', TIMESTAMPADD(SECOND, $kttl, '$now'));"
done


cat <<EOF
/*!40000 ALTER TABLE ${NEW_TABLE} ENABLE KEYS */;
UNLOCK TABLES;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
EOF

