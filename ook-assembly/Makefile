all: ook

ook: ook.o
	ld -o ook ook.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _main -arch arm64

ook.o: ook.s
	as -o ook.o ook.s -arch arm64

clean:
	rm -f ook ook.o
