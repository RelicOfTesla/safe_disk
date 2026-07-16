package sec_utils

// isEnglishLetterSimple checks if a byte is an English letter (A-Z, a-z).
func isEnglishLetterSimple(c byte) bool {
	return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

var _englishLetters [256]byte

func isEnglishLetterMapO1(c byte) bool {
	return _englishLetters[c] == 1
}

func buildEnglishLetterMapO1() [256]byte {
	var result [256]byte
	for c := 'A'; c <= 'Z'; c++ {
		result[byte(c)] = 1
	}
	for c := 'a'; c <= 'z'; c++ {
		result[byte(c)] = 1
	}
	return result
}

var isEnglishLetter = isEnglishLetterMapO1

// isSchemeCharSimple checks if a byte is a valid URI scheme character.
// According to RFC 3986, scheme characters are: A-Z, a-z, 0-9, +, -, .
func isSchemeCharSimple(c byte) bool {
	return ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) ||
		(c >= '0' && c <= '9') ||
		c == '+' || c == '-' || c == '.'
}

var _pathSchemeValidChars [256]byte

func isSchemeCharMapO1(c byte) bool {
	return _pathSchemeValidChars[c] == 1
}

func buildPathSchemeCharMapO1() [256]byte {
	var result [256]byte
	// Add letters (A-Z)
	for c := 'A'; c <= 'Z'; c++ {
		result[byte(c)] = 1
	}
	// Add letters (a-z)
	for c := 'a'; c <= 'z'; c++ {
		result[byte(c)] = 1
	}
	// Add digits (0-9)
	for c := '0'; c <= '9'; c++ {
		result[byte(c)] = 1
	}
	// Add special characters (+, -, .)
	result['+'] = 1
	result['-'] = 1
	result['.'] = 1
	return result
}

var isPathSchemeChar = isSchemeCharMapO1

func init() {
	_englishLetters = buildEnglishLetterMapO1()
	_pathSchemeValidChars = buildPathSchemeCharMapO1()
}
