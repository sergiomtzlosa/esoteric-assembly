import sys

def bf_to_ook(bf_code):
    mapping = {
        '>': 'Ook. Ook? ',
        '<': 'Ook? Ook. ',
        '+': 'Ook. Ook. ',
        '-': 'Ook! Ook! ',
        '.': 'Ook! Ook. ',
        ',': 'Ook. Ook! ',
        '[': 'Ook! Ook? ',
        ']': 'Ook? Ook! '
    }
    ook_code = []
    for char in bf_code:
        if char in mapping:
            ook_code.append(mapping[char])
    return "".join(ook_code)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        try:
            with open(sys.argv[1], 'r') as f:
                bf = f.read()
            print(bf_to_ook(bf))
        except FileNotFoundError:
            # Fallback if user passed string directly or file bad
            print(bf_to_ook(sys.argv[1]))
    else:
        # Default Hello World
        bf = "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
        print(bf_to_ook(bf))
