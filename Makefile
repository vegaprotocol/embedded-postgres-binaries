DEFAULT: all

darwin:
	./gradlew clean install -Pversion=16.4 -PpgVersion=16.4 -PdistName=darwin -ParchName=amd64

alpine:
	./gradlew clean install -Pversion=16.4 -PpgVersion=16.4 -PdistName=alpine -ParchName=amd64

debian:
	./gradlew clean install -Pversion=16.4 -PpgVersion=16.4 -ParchName=amd64

all:
	./gradlew clean install -Pversion=14.1.0 -PpgVersion=16.4 -ParchName=amd64
	./gradlew install -Pversion=16.4 -PpgVersion=16.4 -PdistName=alpine -ParchName=amd64
	./gradlew install -Pversion=16.4 -PpgVersion=16.4 -PdistName=darwin -ParchName=amd64
