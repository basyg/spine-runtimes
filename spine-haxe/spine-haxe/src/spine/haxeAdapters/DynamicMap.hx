package spine.haxeAdapters;

abstract DynamicMap<T>(DynamicAccess<T>) from Dynamic to Dynamic {

	public inline function new() this = {};

	@:arrayAccess
	public inline function get(key:String):Null<T> return this.get(key);

	@:arrayAccess
	public inline function set<T>(key:String, value:T):T return this.set(key, value);

	public inline function exists(key:String):Bool return this.exists(key);

	public inline function remove(key:String):Bool return this.remove(key);

	public inline function keys():Array<String> return this.keys();

	public inline function values():Array<T> {
		var keys = this.keys();
		return [for (key in keys) this.get(key)];
	}

	//public inline function iterator():Iterator<T> return values().iterator();

}
