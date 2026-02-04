all: brainfuck

brainfuck: interpreter.o
	ld -o brainfuck interpreter.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _main -arch arm64

interpreter.o: interpreter.s
	as -o interpreter.o interpreter.s -arch arm64

clean:
	rm -f interpreter.o brainfuck
