.PHONY: build
.PHONY: serve

build:
	cd rosshemsley.co.uk && hugo -d ../docs

serve:
	cd rosshemsley.co.uk && hugo serve -D 
