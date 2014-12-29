#-*- coding: UTF-8 -*-
# Originally written by Jeff Steinmetz, Twitter:  @jeffsteinmetz
# Amended by Phoenix Z Sun, github: github.com/phoenixzsun
# Used for export app logs from worklight analytics platform which is powered by elasticsearch
#
# Updated at 2014.12.27
#
# Requires the Python Elasticsearch client
# http://www.elasticsearch.org/blog/unleash-the-clients-ruby-python-php-perl/#python

'''
Usage:
python analytics.py gadgetName gte_time lte_time [level]
for example:
    python analytics.py HaierApp 2014-11-01 2014-12-22 FATAL
'''

import elasticsearch
import csv
import random
import unicodedata
import sys
import time

def __coustruct_time(shortTime):
    longTime = shortTime + ' 00:00:00'
    timeArray = time.strptime(longTime, "%Y-%m-%d %H:%M:%S")
    timeStamp = int(time.mktime(timeArray))
    return timeStamp * 1000

if len(sys.argv) < 4:
    print 'Usage:'
    print '    python analytics.py appName fromTime toTime level'
    print '  for example:'
    print '    python analytics.py HaierApp 2014-11-01 2014-12-01 FATAL'
    exit()

gadgetName = sys.argv[1]
gte_time = __coustruct_time(sys.argv[2])
lte_time = __coustruct_time(sys.argv[3])
level = ""
conditions = ['ERROR','FATAL','WARN','INFO','DEBUG']
if (len(sys.argv) > 4):
	level = sys.argv[4]
outputfileName = ""
if level != '':
        outputfileName = gadgetName+'.'+sys.argv[2]+'---'+sys.argv[3]+'.'+level+'.csv'
else:
        outputfileName = gadgetName+'.'+sys.argv[2]+'---'+sys.argv[3]+'.csv'
#replace with the IP address of your Elasticsearch node
es = elasticsearch.Elasticsearch(["10.135.16.171:9500"])

if (level != '') and (level not in conditions):
	print 'wrong level!!!'
	exit()
res = ''
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
	}, size=100)  #this is the number of rows to return from the query... to get all queries, run script, see total number of hits, then set euqual to number >= total hits
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
		                  "gte": "1418227200000",
		                  "lte": "1418400000000"
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
	}, size=1000)
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
		}, size=115)

random.seed(1)
sample = res['hits']['hits']
#comment previous line, and un-comment next line for a random sample instead
#randomsample = random.sample(res['hits']['hits'], 5);  #change int to RANDOMLY SAMPLE a certain number of rows from your query

print("Got %d Hits:" % res['hits']['total'])

with open(outputfileName, 'wb') as csvfile:   #set name of output file here
	filewriter = csv.writer(csvfile, delimiter='\t',  # we use TAB delimited, to handle cases where freeform text may have a comma
                            quotechar='|', quoting=csv.QUOTE_MINIMAL)
	# create header row
	filewriter.writerow(["gadgetVersion", "deviceModel", "deviceOs", "environment", "package", "$src", "level", "message"])    #change the column labels here
	for hit in sample:   #switch sample to randomsample if you want a random subset, instead of all rows
		try:			 #try catch used to handle unstructured data, in cases where a field may not exist for a given hit
			col1 = hit["_source"]["worklight_data"]["gadgetVersion"]
		except Exception, e:
			col1 = ""
		try:
			col2 = hit["_source"]["worklight_data"]["deviceModel"].decode('utf-8')  #replace these nested key names with your own
			col2 = col2.replace('\n', ' ')
		except Exception, e:
			col2 = ""
		try:
			col3 = hit["_source"]["worklight_data"]["deviceOs"].decode('utf-8')  #replace these nested key names with your own
			col3 = col3.replace('\n', ' ')
		except Exception, e:
			col3 = ""
                try:
			col4 = hit["_source"]["worklight_data"]["environment"].decode('utf-8')
			col4 = col4.replace('\n', ' ')
		except Exception, e:
			col4 = ""
                try:
			col5 = hit["_source"]["worklight_data"]["package"].decode('utf-8')
			col5 = col5.replace('\n', ' ')
		except Exception, e:
			col5 = ""
                try:
			col6 = hit["_source"]["worklight_data"]["$src"].decode('utf-8')
			col6 = col6.replace('\n', ' ')
		except Exception, e:
			col6 = ""
                try:
			col7 = hit["_source"]["worklight_data"]["level"].decode('utf-8')
			col7 = col7.replace('\n', ' ')
		except Exception, e:
			col7 = ""
                try:
			col8 = hit["_source"]["worklight_data"]["message"].decode('utf-8')
			col8 = col8.replace('\n', ' ')
		except Exception, e:
			col8 = ""
		filewriter.writerow([col1,col2,col3,col4,col5,col6,col7,col8])
