#!/usr/bin/env bash

trap clean_up EXIT

clean_up() {
	test -e ${logs_pipe} && rm -f ${logs_pipe}
	test -e ${ls_output_conf} && rm -f ${ls_output_conf}
}

manage_index_template() {
	template_url_path="_template/template-es-logs"
	template_file_path="@${scriptdir}/elasticsearch/elasticsearch-template-5x.json"
	response=$(curl -XGET ${auth} -s -w "\n%{http_code}\n" ${es_endpoint}/${template_url_path} | tail -1)
	if [[ ${response} -ne "200" ]] || [[ ${force_template_load} ]]; then
		echo -n "Loading Elasticsearch template from ${template_file_path}..."
		response=$(curl -XPUT ${auth} -s -w "\n%{http_code}\n" ${es_endpoint}/${template_url_path} -d ${template_file_path} | tail -1)
		if [[ ${response} -ne "200" ]]; then
			echo -e "\nFailed to load Elasticsearch template! Response: ${response}"
			exit -1
		else
			echo "done!"
		fi
	fi
}

scriptdir=$(readlink -f $0)
scriptdir=$(dirname ${scriptdir})

# Check for xargs binary, die if we can't find it
if ! type -P xargs >/dev/null; then
	echo "Could not find xargs!"
	exit -1
fi

# Check for curl binary, die if we can't find it
if ! type -P curl >/dev/null; then
	echo "Could not find curl!"
	exit -1
fi

# Check we have a Logstash binary we can run
if type -P logstash >/dev/null; then
	LOGSTASH_CMD="$(type -P logstash)"
else
	echo "Could not find logstash!"
	exit -1
fi

# Check for ionice/nice binaries
if type -P ionice 1> /dev/null; then
	LOGSTASH_CMD="$(type -P ionice) -c 3 ${LOGSTASH_CMD}"
fi
if type -P nice 1> /dev/null; then
	LOGSTASH_CMD="$(type -P nice) -n 19 ${LOGSTASH_CMD}"
fi

LOGSTASH_OPTS="--path.config=${scriptdir}/logstash/conf.d --path.settings=${scriptdir}/logstash"
logs_pipe="/tmp/logstash-$$"

while getopts ":h:u:p:t" opt; do
    case $opt in
        h)
			es_endpoint=$OPTARG
            ;;
        u)
			es_username=$OPTARG
            ;;
        p)
			es_password=$OPTARG
			;;
		t)
			force_template_load=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			echo "Ex. usage: $0 -h myes.com:9200 -u user -p password path/to/logs"
			exit -1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			echo "Ex. usage: $0 -h 'https://es:9200' -u user -p password /path/to/some.log"
			exit -1
			;;
    esac
done

if [[ $es_username ]] && [[ $es_password ]]; then
	auth="-u ${es_username}:${es_password}"
else
	auth=""
fi

if ! $(curl -XGET ${auth} -s $es_endpoint | grep tagline 1> /dev/null); then
	echo "$es_endpoint does not seem to be a valid Elasticsearch endpoint."
	exit -1
fi

# Set-up Elasticsearch template
manage_index_template

# Generate output plugin template
echo -n "Creating Logstash output file..."
ls_output_conf=${scriptdir}/logstash/conf.d/90-output-elasticsearch.conf
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
            index => "elasticsearch-logs-5-%{+YYYY.MM.dd}"
		}
	}
EOF
echo "done!"

# Create a pipe for read/write

mkfifo ${logs_pipe}

# Generate input plugin config
shift $(($OPTIND-1))
for f in "$@"; do
	echo "Sending file ${f} to pipe ${logs_pipe}..."
	cat "${f}" > ${logs_pipe} &
done

${LOGSTASH_CMD} ${LOGSTASH_OPTS} < ${logs_pipe} &

wait

exit 0
