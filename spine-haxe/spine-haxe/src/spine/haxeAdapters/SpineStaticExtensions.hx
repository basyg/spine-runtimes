package spine.haxeAdapters;

class SpineStaticExtensions {

	// static public function getStaticField<T>(type:Class<T>, fieldName:String):Dynamic> {
	// 	return Reflect.field(type, fieldName);
	// }

	@:generic
	static public function getSpineEnum<T:{}>(type:Class<T>, enumName:String):T {
		var field;
		if (Reflect.hasField(type, enumName)) {
			field = Reflect.field(type, enumName);
		}
		else {
			var loweredEnumName = enumName.toLowerCase();
			if (Reflect.hasField(type, loweredEnumName)) {
				field = Reflect.field(type, loweredEnumName);
			}
			else {
				var fields = Reflect.fields(type);
				var loweredFields = fields.map(function(field) return field.toLowerCase());
				var index = loweredFields.indexOf(loweredEnumName);
				if (index >= 0) {
					field = Reflect.field(type, fields[index]);
				}
			}
		}
		var enumInstance = Std.instance(field, type);
		if (enumInstance == null) {
			throw new SpineError('enum instance "$enumName" of class "$type" is not found.');
		}
		return enumInstance;
	}

}