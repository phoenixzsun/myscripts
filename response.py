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
    print '    python response.py appName fromTime toTime'
    print '  for example:'
    print '    python response.py HaierApp 2014-11-01 2014-12-01'
    exit()

# Functions

def __coustruct_time(shortTime):
    longTime = shortTime + ' 00:00:00'
    timeArray = time.strptime(longTime, "%Y-%m-%d %H:%M:%S")
    timeStamp = int(time.mktime(timeArray))
    return timeStamp * 1000

def __search(gadgetName, gte_time, lte_time, es, initsize):
    res = ''
    # Replace the following Query with your own Elastic Search Query
    res = es.search(index="worklight", body=
    {
        "query": {
            "bool": {
                "must": [
                            {
                                "term": {
                                    "network_activities.worklight_data.gadgetName": gadgetName
                                 }
                            },
                            {
                                "range": {
                                    "network_activities.worklight_data.daystamp": {
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
        "aggs": {
          "terms": {
            "terms": {
                "field": "worklight_data.daystamp",
                "size": 0,
                "order": {"_term":"asc"}
            },
            "aggs": { 
                "avg_response": { 
                   "avg": {
                      "field": "responseTime" 
                   }
                }
            }

          }
        },
        "sort": [],
        "facets": {}
    }, size=initsize)  #this is the number of rows to return from the query... to get all queries, run script, see total number of hits, then set euqual to number >= total hits

    random.seed(1)
    return res

# starting point
gadgetName = sys.argv[1]
gte_time = __coustruct_time(sys.argv[2])
lte_time = __coustruct_time(sys.argv[3])
# print gte_time
# print lte_time

outputfileName = 'response_'+gadgetName+'.'+sys.argv[2]+'---'+sys.argv[3]+'.xlsx'

#replace with the IP address of your Elasticsearch node
es = elasticsearch.Elasticsearch(["10.135.16.171:9500"])

# the first time just for getting the amount of the total hits(hitcount)
res=__search(gadgetName, gte_time, lte_time, es, 5)
hitcount = res['hits']['total']
print("Got %d Hits:" % hitcount)
# the second query for get all the results
res=__search(gadgetName, gte_time, lte_time, es, hitcount)

sample = res['aggregations']['terms']['buckets']

# Create a workbook and add a worksheet.
workbook = xlsxwriter.Workbook(outputfileName)
worksheet = workbook.add_worksheet()

# Add a bold format to use to highlight cells.
bold = workbook.add_format({'bold': True})

# Widen columns to make the text clearer.
worksheet.set_column('A:A', 20)
worksheet.set_column('B:B', 20)

# Write some data header.
worksheet.write('B1', 'avg_response', bold)
worksheet.write('A1', 'daystamp', bold)

# Write data
row = 1
col = 0
for hit in sample:
  # if ('responseTime' in hit["_source"]["worklight_data"]):
  #   worksheet.write(row, col, hit["_source"]["worklight_data"]["gadgetVersion"])
  #   worksheet.write(row, col+1, hit["_source"]["worklight_data"]["deviceModel"])
  #   worksheet.write(row, col+2, hit["_source"]["worklight_data"]["deviceOs"])
  #   worksheet.write(row, col+3, hit["_source"]["worklight_data"]["environment"])
  #   if ('package' in hit["_source"]["worklight_data"]):
  #     worksheet.write(row, col+4, hit["_source"]["worklight_data"]["package"])
  #   worksheet.write(row, col+5, hit["_source"]["worklight_data"]["responseTime"])
  #   if ('path' in hit["_source"]["worklight_data"]):
  #     worksheet.write(row, col+7, hit["_source"]["worklight_data"]["path"])
  #   if ('procedure' in hit["_source"]["worklight_data"]):
  #     worksheet.write(row, col+6, hit["_source"]["worklight_data"]["procedure"])
  #   worksheet.write(row, col+8, hit["_source"]["worklight_data"]["daystamp"])
  tempTime = hit["key"] / 1000
  toBeCon = time.localtime(tempTime)
  converted = time.strftime('%Y-%m-%d',toBeCon)
  print converted
  worksheet.write(row, col, converted)
  worksheet.write(row, col+1, hit["avg_response"]["value"])
  row += 1
workbook.close()
