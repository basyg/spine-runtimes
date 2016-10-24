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

package spine.animation;
import spine.MathUtils;
import spine.Event;
import spine.Skeleton;

/** Base class for frames that use an interpolation bezier curve. */
class CurveTimeline implements Timeline {
	static private inline var LINEAR:Number = 0;
	static private inline var STEPPED:Number = 1;
	static private inline var BEZIER:Number = 2;
	static private inline var BEZIER_SIZE:Int = 10 * 2 - 1;

	private var curves:Vector<Number>; // type, x, y, ...

	public function new (frameCount:Int) {
		curves = new Vector<Number>((frameCount - 1) * BEZIER_SIZE, true);
	}

	public function apply (skeleton:Skeleton, lastTime:Number, time:Number, firedEvents:Vector<Event>, alpha:Number) : Void {
	}

	public var frameCount(get, never):Int;
	inline function get_frameCount () : Int {
		return int(curves.length / BEZIER_SIZE) + 1;
	}

	public function setLinear (frameIndex:Int) : Void {
		curves[int(frameIndex * BEZIER_SIZE)] = LINEAR;
	}

	public function setStepped (frameIndex:Int) : Void {
		curves[int(frameIndex * BEZIER_SIZE)] = STEPPED;
	}

	/** Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
	 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
	 * the difference between the keyframe's values. */
	public function setCurve (frameIndex:Int, cx1:Number, cy1:Number, cx2:Number, cy2:Number) : Void {
		var tmpx:Number = (-cx1 * 2 + cx2) * 0.03, tmpy:Number = (-cy1 * 2 + cy2) * 0.03;
		var dddfx:Number = ((cx1 - cx2) * 3 + 1) * 0.006, dddfy:Number = ((cy1 - cy2) * 3 + 1) * 0.006;
		var ddfx:Number = tmpx * 2 + dddfx, ddfy:Number = tmpy * 2 + dddfy;
		var dfx:Number = cx1 * 0.3 + tmpx + dddfx * 0.16666667, dfy:Number = cy1 * 0.3 + tmpy + dddfy * 0.16666667;

		var i:Int = frameIndex * BEZIER_SIZE;
		var curves:Vector<Number> = this.curves;
		curves[int(i++)] = BEZIER;

		var x:Number = dfx, y:Number = dfy, n:Int = i + BEZIER_SIZE - 1;
		while (i < n) {
			curves[i] = x;
			curves[int(i + 1)] = y;
			dfx += ddfx;
			dfy += ddfy;
			ddfx += dddfx;
			ddfy += dddfy;
			x += dfx;
			y += dfy;
			i += 2;
		}
	}

	public function getCurvePercent (frameIndex:Int, percent:Number) : Number {
		percent = MathUtils.clamp(percent, 0, 1);
		var curves:Vector<Number> = this.curves;
		var i:Int = frameIndex * BEZIER_SIZE;
		var type:Number = curves[i];
		if (type == LINEAR) return percent;
		if (type == STEPPED) return 0;
		i++;
		var x:Number = 0;
		var start:Int = i, n:Int = i + BEZIER_SIZE - 1;
		while (i < n) {
			x = curves[i];
			if (x >= percent) {
				var prevX:Number, prevY:Number;
				if (i == start) {
					prevX = 0;
					prevY = 0;
				} else {
					prevX = curves[int(i - 2)];
					prevY = curves[int(i - 1)];
				}
				return prevY + (curves[int(i + 1)] - prevY) * (percent - prevX) / (x - prevX);
			}
			i += 2;
		}
		var y:Number = curves[int(i - 1)];
		return y + (1 - y) * (percent - x) / (1 - x); // Last point is 1,1.
	}
}
