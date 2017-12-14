.PHONY: image run_local remote_image deploy

image:
	docker build -t daviddyball/ablog:latest .


remote_image: image
	docker push daviddyball/ablog:latest


run_local: image
	docker run -ti --rm -p 80:80 daviddyball/ablog:latest


deploy: remote_image
	cd terraform && terraform init && terraform apply

