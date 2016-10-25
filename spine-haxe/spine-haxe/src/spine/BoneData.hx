/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

package spine;

class BoneData {
	@:allow(spine) var _index:Int;
	@:allow(spine) var _name:String;
	@:allow(spine) var _parent:BoneData;
	public var length:Number = Default.float;
	public var x:Number = Default.float;
	public var y:Number = Default.float;
	public var rotation:Number = Default.float;
	public var scaleX:Number = 1;
	public var scaleY:Number = 1;
	public var shearX:Number = Default.float;
	public var shearY:Number = Default.float;	
	public var inheritRotation:Bool = true;
	public var inheritScale:Bool = true;

	/** @param parent May be null. */
	public function new (index:Int, name:String, parent:BoneData) {
		if (index < 0) throw new ArgumentError("index must be >= 0");
		if (name == null) throw new ArgumentError("name cannot be null.");
		_index = index;
		_name = name;
		_parent = parent;
	}
	
	public var index(get, never):Int;
	inline function get_index () : Int {
		return _index;
	}

	public var name(get, never):String;
	inline function get_name () : String {
		return _name;
	}

	/** @return May be null. */
	public var parent(get, never):BoneData;
	inline function get_parent () : BoneData {
		return _parent;
	}

	public function toString () : String {
		return _name;
	}
}
