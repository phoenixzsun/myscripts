#-*- coding: UTF-8 -*-
# Written by Phoenix Z Sun, github: github.com/phoenixzsun
# Used for export app logs from worklight analytics platform which is powered by elasticsearch
# Updated at 2015.01.06
# Requires the Python Elasticsearch client
# http://www.elasticsearch.org/blog/unleash-the-clients-ruby-python-php-perl/#python

import elasticsearch
import csv
import random
import unicodedata
import sys
import time
import xlsxwriter

if len(sys.argv) < 4:
    print 'Usage:'
    print '    python new_analytics.py appName fromTime toTime level'
    print '  for example:'
    print '    python new_analytics.py HaierApp 2014-11-01 2014-12-01 FATAL'
    exit()

# Functions

def __coustruct_time(shortTime):
    longTime = shortTime + ' 00:00:00'
    timeArray = time.strptime(longTime, "%Y-%m-%d %H:%M:%S")
    timeStamp = int(time.mktime(timeArray))
    return timeStamp * 1000

def __search(level, conditions, gadgetName, gte_time, lte_time, es, initsize):
    res = ''
    if (level != '') and (level not in conditions):
            print 'wrong level!!!'
            exit()
    if (level in ['WARN','INFO','DEBUG']) or (level == ''):
            # Replace the following Query with your own Elastic Search Query
            res = es.search(index="worklight", body=
            {
                "query": {
                    "bool": {
                        "must": [
                                    {
                                        "term": {
                                            "client_logs.worklight_data.gadgetName": gadgetName
                                         }
                                    }, {
                                        "range": {
                                            "client_logs.worklight_data.timestamp": {
                                                "gte": gte_time,
                                                "lte": lte_time
                                            }
                                        }
                                    }
                                ],
                        "must_not": [],
                        "should": []
                    }
                },
                "from": 0,
                "size": 10,
                "sort": [],
                "facets": {}
            }, size=initsize)  #this is the number of rows to return from the query... to get all queries, run script, see total number of hits, then set euqual to number >= total hits
    elif level == 'ERROR':
            res = es.search(index="worklight", body=
            {
                    "query": {
                        "filtered": {
                          "query": {
                            "bool" :{
                                    "must":[
                                            {"term":{"client_logs.worklight_data.gadgetName": gadgetName}}
                                    ]
                            }
                          },
                          "filter": {
                            "bool": {
                              "should": [
                                {"term":{"client_logs.worklight_data.level":"ERROR"}},
                                {"term":{"client_logs.worklight_data.level":"FATAL"}}
                              ],
                              "must": [
                                {
                                  "range": {
                                    "client_logs.worklight_data.timestamp": {
                                      "gte": gte_time,
                                      "lte": lte_time
                                    }
                                  }
                                }
                              ]
                            }
                          }
                        }
                      },
                "from": 0,
                "size": 10,
                "sort": [],
                "facets": {}
            }, size=initsize)
    else:
            if level == 'FATAL':
                    res = es.search(index="worklight", body=
                    {
                        "query": {
                                    "bool": {
                                          "must": [
                                            {
                                              "term": {
                                                "client_logs.worklight_data.gadgetName": gadgetName
                                              }
                                            },
                                            {
                                              "term": {
                                                "client_logs.worklight_data.level": "FATAL"
                                              }
                                            },
                                            {
                                              "range": {
                                                "client_logs.worklight_data.timestamp": {
                                                  "gte": gte_time,
                                                  "lte": lte_time
                                                }
                                              }
                                            }
                                          ],
                                          "must_not": [],
                                          "should": []
                                     }
                        },
                        "from": 0,
                        "size": 10,
                        "sort": [],
                        "facets": {}
                    }, size=initsize)
    random.seed(1)
    return res

gadgetName = sys.argv[1]
gte_time = __coustruct_time(sys.argv[2])
lte_time = __coustruct_time(sys.argv[3])
level = ""
conditions = ['ERROR','FATAL','WARN','INFO','DEBUG']
if (len(sys.argv) > 4):
	level = sys.argv[4]
outputfileName = ""
if level != '':
        outputfileName = gadgetName+'.'+sys.argv[2]+'---'+sys.argv[3]+'.'+level+'.xlsx'
else:
        outputfileName = gadgetName+'.'+sys.argv[2]+'---'+sys.argv[3]+'.xlsx'

#replace with the IP address of your Elasticsearch node
es = elasticsearch.Elasticsearch(["10.135.16.171:9500"])

res=__search(level, conditions, gadgetName, gte_time, lte_time, es, 5)
#print res['hits']['total']
hitcount = res['hits']['total']
print("Got %d Hits:" % hitcount)
#print hitcount
res=__search(level, conditions, gadgetName, gte_time, lte_time, es, hitcount)

sample = res['hits']['hits']

# Create a workbook and add a worksheet.
workbook = xlsxwriter.Workbook(outputfileName)
worksheet = workbook.add_worksheet()

# Add a bold format to use to highlight cells.
bold = workbook.add_format({'bold': True})

# Widen the first column to make the text clearer.
worksheet.set_column('A:A', 15)
worksheet.set_column('B:B', 12)
worksheet.set_column('C:C', 12)
worksheet.set_column('D:D', 12)
worksheet.set_column('E:E', 20)
worksheet.set_column('F:F', 10)
worksheet.set_column('G:G', 10)
worksheet.set_column('H:H', 70)

# Write some data header.
worksheet.write('A1', 'gadgetVersion', bold)
worksheet.write('B1', 'deviceModel', bold)
worksheet.write('C1', 'deviceOs', bold)
worksheet.write('D1', 'environment', bold)
worksheet.write('E1', 'package', bold)
worksheet.write('F1', '$src', bold)
worksheet.write('G1', 'level', bold)
worksheet.write('H1', 'message', bold)

# Write data
row = 1
col = 0
for hit in sample:
    worksheet.write(row, col, hit["_source"]["worklight_data"]["gadgetVersion"])
    worksheet.write(row, col+1, hit["_source"]["worklight_data"]["deviceModel"])
    worksheet.write(row, col+2, hit["_source"]["worklight_data"]["deviceOs"])
    worksheet.write(row, col+3, hit["_source"]["worklight_data"]["environment"])
    worksheet.write(row, col+4, hit["_source"]["worklight_data"]["package"])
    worksheet.write(row, col+5, hit["_source"]["worklight_data"]["$src"])
    worksheet.write(row, col+6, hit["_source"]["worklight_data"]["level"])
    worksheet.write(row, col+7, hit["_source"]["worklight_data"]["message"])
    row += 1

workbook.close()
