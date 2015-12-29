## What is this?

This is a way to visualise Elasticsearch logs (not slow logs) in
Kibana.  See the following screenshot for what it looks like:

[[Dashboard-Screenshot.png|alt=Dashboard]]

## Installation

### Requirements

* Elasticsearch 2.1.x or higher
* Kibana 4.3.x or higher
* Logstash 2.1.x or higher

### Setup

#### 1. Load Elasticsearch mapping template

Load the Elasticsearch mapping template in
`elasticsearch/elasticsearch-template.json`:

```
curl -XPUT <eshost>:<esport>/_template/es-logs -d @elasticsearch/elasticsearch-template.json
```

Replace `<eshost>` and `<esport>` to your Elasticsearch ip/host and
port combo.

#### 2. Import Kibana dashboard/visualisations

Import the Kibana dashboard/visualisations in `kibana/export.json`

## Usage

Adjust the *output* in the logstash configuration file
`logstash/90-output-elasticsearch.conf`  appropriate for
your Elasticsearch server.  **DO NOT CHANGE THE INDEX NAME**.
Then simply `cat` your log files to logstash using this configuration file:

```
cat /path/to/elasticsearch.log | /path/to/bin/logstash --config logstash
```

## Limitations

* Log lines that have unexpected newlines or other control characters
  at random places will not be processed correctly.  Look for
  documents tagged `_grokparsefailure` to see these.

## Contributing

Most of the time you'll probably want to add new Logstash filters to
parse various components not already handled here.  You may also need
to update the dynamic template mapping used by the index if you add
new fields or import/export a new dashboard/visualisation from/to Kibana.

### Elasticsearch

The mapping file is located at
[[elasticsearch/elasticsearch-template.json]].  After editing, you'll
need to update the mapping in your Elasticsearch cluster with the curl
command above and reindex any log files.

### Logstash

All of the filters for a base component of logging in Elasticsearch
go into a seperate `logstash/50-filter-<component>.conf` Logstash configuration file. So
for example, filters for **index.shard** and **index.fielddata** log
messages go into a `50-filter-index.conf` Logstash configuration file.

The following standard input, filter and output configuration files
also exist:

* `10-input-stdin.conf`: for reading stdin.
* `40-filter-base.conf`: base filter configuration to parse timestamp,
log level and component.
* `45-filter-exceptions.conf`: parses multiline java stack traces.
* `90-output-dots.conf`: outputs a `.` to the console for each log
line processed.
* `90-output-elasticsearch.conf`: output to Elasticsearch.

Excluding `90-output-elasticsearch.conf`, there should be no need to
edit these files.

### Kibana

The dashboards and visualisations shown in the screenshot are in the
[[kibana/export.json]] file.
