package spine.haxeAdapters;

import haxe.macro.Expr;
import haxe.macro.Context;

using haxe.macro.Tools;

class SpineMacroStaticExtensions {

	macro static public function safeCast<T,T2>(eToType:ExprOf<Class<T>>, eInstance:ExprOf<T2>):ExprOf<T> {
		var type = Context.getType(getExprOfThis(eToType).toString());
		var complexType = type.toComplexType();
		return macro (cast $eInstance:$complexType);
	}

	#if macro
	static function getExprOfThis(thisExpr:Expr):Expr {
		return switch (thisExpr.expr) {
			case ExprDef.EMeta({ name: ':this' } , { expr: EConst(CIdent('this')) }):
				Context.getTypedExpr(Context.typeExpr(thisExpr));
			default:
				thisExpr;
		}
	}
	#end
	
}