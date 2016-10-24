package spine.haxeAdapters;

typedef Error = SpineError;

typedef ArgumentError = SpineError;

typedef RuntimeException = SpineError;

typedef IllegalStateException = SpineError;

typedef SerializationException = SpineError;

class SpineError {

	public var message(default, null):String;

	public function new(message:String) {
		this.message = message;
	}

    public function toString():String {
        return 'SpineError: $message';
    }
	
}