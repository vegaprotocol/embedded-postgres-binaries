DEFAULT: all

darwin:
	./gradlew clean install -Pversion=16.0.4 -PpgVersion=16.0 -PdistName=darwin -ParchName=amd64

alpine:
	./gradlew clean install -Pversion=16.0.4 -PpgVersion=16.0 -PdistName=alpine -ParchName=amd64

debian:
	./gradlew clean install -Pversion=16.0.4 -PpgVersion=16.0 -ParchName=amd64

all:
	./gradlew clean install -Pversion=16.0.3 -PpgVersion=16.0 -ParchName=amd64
	./gradlew install -Pversion=16.0.3 -PpgVersion=16.0 -PdistName=alpine -ParchName=amd64
	./gradlew install -Pversion=16.0.3 -PpgVersion=16.0 -PdistName=darwin -ParchName=amd64
