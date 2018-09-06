import sys

def main():
    arguments = sys.argv[1:];
    print("[")
    for filename in arguments:    
        with open(filename) as f:
            lines = f.readlines()
    
        for line in lines:
            if "Fn::Join" in line:
                continue
            escaped_line = line.replace('"', '\\"')
            print('"' + escaped_line.strip('\n')+ '",')
    
    print("]")
if __name__ == "__main__":
    main()
