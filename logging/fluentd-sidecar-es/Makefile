.PHONY:	build push

TAG = v0.0.1

build:
	docker build -t cargo.caicloud.io/caicloud/fluentd-sidecar-es:$(TAG) .

push:
	gcloud docker push cargo.caicloud.io/caicloud/fluentd-sidecar-es:$(TAG)
