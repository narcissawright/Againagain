extends RefCounted
class_name NetworkConst

# shared constants for the client or server to reference

const VERSION:String = "0.1" # Game version must match client.
const PORT:int = 8888

const USERNAME_LENGTH_MAX:int = 16
const USERNAME_LENGTH_MIN:int = 1

enum Error {
	ARGUMENT_TYPE_MISMATCH,
	VERSION_MISMATCH,
	USERNAME_INVALID,
	USERNAME_RESERVED,
	SECRETKEY_MISMATCH,
	NOT_LOGGED_IN,
	BAD_DATA
	}
