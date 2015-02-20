Originally based of [tutumcloud/tutum-docker-mysql](https://github.com/tutumcloud/tutum-docker-mysql), credits to them :D

## Run MySQL in a container on top of Ubuntu:Trusty

	docker build \
		 --tag crobays/mysql \
		 .

	docker run \
		-v ./:/project \
		-e PUBLIC_PATH=/project/public \
		-e TIMEZONE=Etc/UTC \
		-e USER=admin \
		-e PASS=secret \
		-e DATABASE=default \
		-e SQL_DUMP_FILE=your-sql-dump.sql \
		--name mysql \
		-it --rm \
		crobays/mysql

# Create a webserver with [crobays/nginx-php](https://github.com/crobays/docker-nginx-php)

	docker run \
		--link mysql:db \
		-v ./:/project \
		-e PUBLIC_PATH=/project/public \
		-e TIMEZONE=Etc/UTC \
		-it --rm \
		crobays/nginx-php