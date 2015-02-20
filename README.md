ORIGINALLY BASED OF TUTUM/MYSQL, CREDITS TO THEM :D

## Run MySQL in a container on top of Ubuntu:Trusty

	docker build \
		 --name crobays/mysql \
		 .

	docker run \
		-v ./:/project \
		-e PUBLIC_PATH=/project/public \
		-e TIMEZONE=Etc/UTC \
		-e ENVIRONMENT=prod \
		-e USER=admin \
		-e PASS=secret \
		-e DATABASE=default \
		-e SQL_DUMP_FILE=your-sql-dump.sql \
		crobays/mysql
