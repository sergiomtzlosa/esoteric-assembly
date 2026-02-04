all: befunge

befunge: befunge.o
	ld -o befunge befunge.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _main -arch arm64

befunge.o: befunge.s
	as -o befunge.o befunge.s -arch arm64

clean:
	rm -f befunge befunge.o
