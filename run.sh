docker-compose down
if [ "${1}" = "down" ]; then
        exit
elif [ -n "${1}" ]; then
        docker-compose build
        docker-compose run --rm ${*}
else
        docker-compose up --build
fi
