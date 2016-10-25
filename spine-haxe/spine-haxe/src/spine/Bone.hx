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

class Bone implements Updatable {
	static public var yDown:Bool;

	@:allow(spine) var _data:BoneData;
	@:allow(spine) var _skeleton:Skeleton;
	@:allow(spine) var _parent:Bone;
	@:allow(spine) var _children:Vector<Bone> = new Vector<Bone>();
	public var x:Number = Default.float;
	public var y:Number = Default.float;
	public var rotation:Number = Default.float;
	public var scaleX:Number = Default.float;
	public var scaleY:Number = Default.float;
	public var shearX:Number = Default.float;
	public var shearY:Number = Default.float;
	public var appliedRotation:Number = Default.float;	

	@:allow(spine) var _a:Number = Default.float;
	@:allow(spine) var _b:Number = Default.float;
	@:allow(spine) var _c:Number = Default.float;
	@:allow(spine) var _d:Number = Default.float;
	@:allow(spine) var _worldX:Number = Default.float;
	@:allow(spine) var _worldY:Number = Default.float;
	@:allow(spine) var _worldSignX:Number = Default.float;
	@:allow(spine) var _worldSignY:Number = Default.float;
	
	@:allow(spine) var _sorted:Bool;

	/** @param parent May be null. */
	public function new (data:BoneData, skeleton:Skeleton, parent:Bone) {
		if (data == null) throw new ArgumentError("data cannot be null.");
		if (skeleton == null) throw new ArgumentError("skeleton cannot be null.");
		_data = data;
		_skeleton = skeleton;
		_parent = parent;
		setToSetupPose();
	}
	
	/** Same as updateWorldTransform(). This method exists for Bone to implement Updatable. */
	public function update () : Void {
	 	updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
	}

	/** Computes the world SRT using the parent bone and this bone's local SRT. */
	public function updateWorldTransform () : Void {
		updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
	}

	/** Computes the world SRT using the parent bone and the specified local SRT. */
	public function updateWorldTransformWith (x:Number, y:Number, rotation:Number, scaleX:Number, scaleY:Number, shearX:Number, shearY:Number) : Void {
		appliedRotation = rotation;

		var rotationY:Number = rotation + 90 + shearY;
		var la:Number = MathUtils.cosDeg(rotation + shearX) * scaleX, lb:Number = MathUtils.cosDeg(rotationY) * scaleY;
		var lc:Number = MathUtils.sinDeg(rotation + shearX) * scaleX, ld:Number = MathUtils.sinDeg(rotationY) * scaleY;
		
		var parent:Bone = _parent;
		if (parent == null) { // Root bone.
			var skeleton:Skeleton = _skeleton;
			if (skeleton.flipX) {
				x = -x;
				la = -la;
				lb = -lb;
			}
			if (skeleton.flipY != yDown) {
				y = -y;
				lc = -lc;
				ld = -ld;
			}
			_a = la;
			_b = lb;
			_c = lc;
			_d = ld;
			_worldX = x;
			_worldY = y;
			_worldSignX = scaleX < 0 ? -1 : 1;
			_worldSignY = scaleY < 0 ? -1 : 1;
			return;
		}

		var pa:Number = parent._a, pb:Number = parent._b, pc:Number = parent._c, pd:Number = parent._d;
		_worldX = pa * x + pb * y + parent._worldX;
		_worldY = pc * x + pd * y + parent._worldY;
		_worldSignX = parent._worldSignX * (scaleX < 0 ? -1 : 1);
		_worldSignY = parent._worldSignY * (scaleY < 0 ? -1 : 1);

		if (data.inheritRotation && data.inheritScale) {
			_a = pa * la + pb * lc;
			_b = pa * lb + pb * ld;
			_c = pc * la + pd * lc;
			_d = pc * lb + pd * ld;
		} else {
			if (data.inheritRotation) { // No scale inheritance.
				pa = 1;
				pb = 0;
				pc = 0;
				pd = 1;
				do {
					var cos:Number = MathUtils.cosDeg(parent.appliedRotation), sin:Number = MathUtils.sinDeg(parent.appliedRotation);
					var temp:Number = pa * cos + pb * sin;
					pb = pb * cos - pa * sin;
					pa = temp;
					temp = pc * cos + pd * sin;
					pd = pd * cos - pc * sin;
					pc = temp;
	
					if (!parent.data.inheritRotation) break;
					parent = parent.parent;
				} while (parent != null);
				_a = pa * la + pb * lc;
				_b = pa * lb + pb * ld;
				_c = pc * la + pd * lc;
				_d = pc * lb + pd * ld;
			} else if (data.inheritScale) { // No rotation inheritance.
				pa = 1;
				pb = 0;
				pc = 0;
				pd = 1;
				do {
					var cos:Number = MathUtils.cosDeg(parent.appliedRotation), sin:Number = MathUtils.sinDeg(parent.appliedRotation);
					var psx:Number = parent.scaleX, psy:Number = parent.scaleY;
					var za:Number = cos * psx, zb:Number = sin * psy, zc:Number = sin * psx, zd:Number = cos * psy;
					var temp:Number = pa * za + pb * zc;
					pb = pb * zd - pa * zb;
					pa = temp;
					temp = pc * za + pd * zc;
					pd = pd * zd - pc * zb;
					pc = temp;

					if (psx >= 0) sin = -sin;
					temp = pa * cos + pb * sin;
					pb = pb * cos - pa * sin;
					pa = temp;
					temp = pc * cos + pd * sin;
					pd = pd * cos - pc * sin;
					pc = temp;
	
					if (!parent.data.inheritScale) break;
					parent = parent.parent;
				} while (parent != null);
				_a = pa * la + pb * lc;
				_b = pa * lb + pb * ld;
				_c = pc * la + pd * lc;
				_d = pc * lb + pd * ld;
			} else {
				_a = la;
				_b = lb;
				_c = lc;
				_d = ld;
			}
			if (_skeleton.flipX) {
				_a = -_a;
				_b = -_b;
			}
			if (_skeleton.flipY != yDown) {
				_c = -_c;
				_d = -_d;
			}
		}
	}

	public function setToSetupPose () : Void {
		x = _data.x;
		y = _data.y;
		rotation = _data.rotation;
		scaleX = _data.scaleX;
		scaleY = _data.scaleY;
		shearX = _data.shearX;
		shearY = _data.shearY;
	}

	public var data(get, never):BoneData;
	inline function get_data () : BoneData {
		return _data;
	}

	public var skeleton(get, never):Skeleton;
	inline function get_skeleton () : Skeleton {
		return _skeleton;
	}

	public var parent(get, never):Bone;
	inline function get_parent () : Bone {
		return _parent;
	}

	public var children(get, never):Vector<Bone>;
	inline function get_children () : Vector<Bone> {
		return _children;
	}

	public var a(get, never):Number;
	inline function get_a () : Number {
		return _a;
	}

	public var b(get, never):Number;
	inline function get_b () : Number {
		return _b;
	}

	public var c(get, never):Number;
	inline function get_c () : Number {
		return _c;
	}

	public var d(get, never):Number;
	inline function get_d () : Number {
		return _d;
	}

	public var worldX(get, never):Number;
	inline function get_worldX () : Number {
		return _worldX;
	}

	public var worldY(get, never):Number;
	inline function get_worldY () : Number {
		return _worldY;
	}

	public var worldSignX(get, never):Number;
	inline function get_worldSignX () : Number {
		return _worldSignX;
	}

	public var worldSignY(get, never):Number;
	inline function get_worldSignY () : Number {
		return _worldSignY;
	}

	public var worldRotationX(get, never):Number;
	inline function get_worldRotationX () : Number {
		return Math.atan2(_c, _a) * MathUtils.radDeg;
	}

	public var worldRotationY(get, never):Number;
	inline function get_worldRotationY () : Number {
		return Math.atan2(_d, _b) * MathUtils.radDeg;
	}

	public var worldScaleX(get, never):Number;
	inline function get_worldScaleX () : Number {
		return Math.sqrt(_a * _a + _b * _b) * _worldSignX;
	}

	public var worldScaleY(get, never):Number;
	inline function get_worldScaleY () : Number {
		return Math.sqrt(_c * _c + _d * _d) * _worldSignY;
	}
	
	public function worldToLocalRotationX () : Number {
		var parent:Bone = _parent;
		if (parent == null) return rotation;
		var pa:Number = parent.a, pb:Number = parent.b, pc:Number = parent.c, pd:Number = parent.d, a:Number = this.a, c:Number = this.c;
		return Math.atan2(pa * c - pc * a, pd * a - pb * c) * MathUtils.radDeg;
	}

	public function worldToLocalRotationY () : Number {
		var parent:Bone = _parent;
		if (parent == null) return rotation;
		var pa:Number = parent.a, pb:Number = parent.b, pc:Number = parent.c, pd:Number = parent.d, b:Number = this.b, d:Number = this.d;
		return Math.atan2(pa * d - pc * b, pd * b - pb * d) * MathUtils.radDeg;
	}

	public function rotateWorld (degrees:Number) : Void {
		var a:Number = this.a, b:Number = this.b, c:Number = this.c, d:Number = this.d;
		var cos:Number = MathUtils.cosDeg(degrees), sin:Number = MathUtils.sinDeg(degrees);
		this._a = cos * a - sin * c;
		this._b = cos * b - sin * d;
		this._c = sin * a + cos * c;
		this._d = sin * b + cos * d;
	}

	/** Computes the local transform from the world transform. This can be useful to perform processing on the local transform
	 * after the world transform has been modified directly (eg, by a constraint).
	 * <p>
	 * Some redundant information is lost by the world transform, such as -1,-1 scale versus 180 rotation. The computed local
	 * transform values may differ from the original values but are functionally the same. */
	public function updateLocalTransform () : Void {
		var parent:Bone = this.parent;
		if (parent == null) {
			x = worldX;
			y = worldY;
			rotation = Math.atan2(c, a) * MathUtils.radDeg;
			scaleX = Math.sqrt(a * a + c * c);
			scaleY = Math.sqrt(b * b + d * d);
			var det:Number = a * d - b * c;
			shearX = 0;
			shearY = Math.atan2(a * b + c * d, det) * MathUtils.radDeg;
			return;
		}
		var pa:Number = parent.a, pb:Number = parent.b, pc:Number = parent.c, pd:Number = parent.d;
		var pid:Number = 1 / (pa * pd - pb * pc);
		var dx:Number = worldX - parent.worldX, dy:Number = worldY - parent.worldY;
		x = (dx * pd * pid - dy * pb * pid);
		y = (dy * pa * pid - dx * pc * pid);
		var ia:Number = pid * pd;
		var id:Number = pid * pa;
		var ib:Number = pid * pb;
		var ic:Number = pid * pc;
		var ra:Number = ia * a - ib * c;
		var rb:Number = ia * b - ib * d;
		var rc:Number = id * c - ic * a;
		var rd:Number = id * d - ic * b;
		shearX = 0;
		scaleX = Math.sqrt(ra * ra + rc * rc);
		if (scaleX > 0.0001) {
			var det:Number = ra * rd - rb * rc;
			scaleY = det / scaleX;
			shearY = Math.atan2(ra * rb + rc * rd, det) * MathUtils.radDeg;
			rotation = Math.atan2(rc, ra) * MathUtils.radDeg;
		} else {
			scaleX = 0;
			scaleY = Math.sqrt(rb * rb + rd * rd);
			shearY = 0;
			rotation = 90 - Math.atan2(rd, rb) * MathUtils.radDeg;
		}
		appliedRotation = rotation;
	}

	public function worldToLocal (world:Vector<Number>) : Void {
		var a:Number = _a, b:Number = _b, c:Number = _c, d:Number = _d;
		var invDet:Number = 1 / (a * d - b * c);
		var x:Number = world[0] - _worldX, y:Number = world[1] - _worldY;				
		world[0] = (x * d * invDet - y * b * invDet);
		world[1] = (y * a * invDet - x * c * invDet);
	}

	public function localToWorld (local:Vector<Number>) : Void {
		var localX:Number = local[0], localY:Number = local[1];
		local[0] = localX * _a + localY * _b + _worldX;
		local[1] = localX * _c + localY * _d + _worldY;
	}

	public function toString () : String {
		return _data._name;
	}
}
