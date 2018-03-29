import sys

def main():
    arguments = sys.argv[1:];
    filename = arguments[0]
    with open(filename) as f:
        lines = f.readlines()
    
    print("[")
    for line in lines:
        escaped_line = line.replace('"', '\\"')
        print('"' + escaped_line.strip('\n')+ '",')
    
    print("]")
if __name__ == "__main__":
    main()
