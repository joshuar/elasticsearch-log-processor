#!/usr/bin/env bash

generate_elasticsearch_output() {
	echo "Creating Logstash output file"
	ls_output_conf=${scriptdir}/logstash/90-output-elasticsearch.conf
	cat > ${ls_output_conf}<<EOF
output {
    elasticsearch {
        hosts => [ "${es_endpoint}" ]
EOF
	if [[ $es_username ]] && [[ $es_password ]]; then
		cat >> ${ls_output_conf}<<EOF
		user => "${es_username}"
		password => "${es_password}"
EOF
	fi
	cat >> ${ls_output_conf}<<EOF
        index => "elasticsearch-logs-%{+YYYY.MM.dd}"
    }
}
EOF
}

manage_index_template() {
	template_url_path="_template/template-es-logs"
	template_file_path="@${scriptdir}/elasticsearch/elasticsearch-template.json"
	if [[ $es_username ]] && [[ $es_password ]]; then
		auth="-u ${es_username}:${es_password}"
	else
		auth=""
	fi
	response=$(curl -XGET ${auth} -s -w "\n%{http_code}\n" ${es_endpoint}/${template_url_path} | tail -1)
	if [[ ${response} -ne "200" ]]; then
		echo "Loading Elasticsearch template from ${template_file_path}"
		response=$(curl -XPUT ${auth} -s -w "\n%{http_code}\n" ${es_endpoint}/${template_url_path} -d ${template_file_path} | tail -1)
		if [[ ${response} -ne "200" ]]; then
			echo "Failed to load Elasticsearch template! Response: ${response}"
			exit -1
		fi
	fi
}


scriptdir=$(dirname $0)

if ! type -P curl >/dev/null; then
	echo "Could not find curl!"
	exit -1
fi

if ! type -P logstash >/dev/null; then
	echo "Could not find logstash!"
	exit -1
fi

while getopts ":h:u:p:" opt; do
    case $opt in
        h)
			es_endpoint=$OPTARG
			if ! $(curl -s $es_endpoint | grep tagline 1> /dev/null); then
				echo "$es_endpoint does not seem to be a valid Elasticsearch endpoint."
				exit -1
			fi
            ;;
        u)
			es_username=$OPTARG
            ;;
        p)
			es_password=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			echo "Ex. usage: $0 -h myes.com:9200 -u user -p password path/to/logs"
			exit -1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			echo "Ex. usage: $0 -n 'John Doe' -e john@doe.com -u john"
			exit -1
			;;
    esac
done

manage_index_template
generate_elasticsearch_output

# find $* -type f -print0 | xargs nice -n 19 ionice -c 3 logstash -f ${scriptdir}/logstash < -

# test -e ${ls_output_conf} && rm ${ls_output_conf}


exit 0
