CFLAGS = -Werror -Wall
LDFLAGS = -framework Foundation -framework CoreLocation

default: run

get-location: get-location.o

run: get-location
	./get-location
