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

import spine.Event;
import spine.Skeleton;

class AnimationState {
	private var _data:AnimationStateData;
	private var _tracks:Vector<TrackEntry> = new Vector<TrackEntry>();
	private var _events:Vector<Event> = new Vector<Event>();
	public var onStart:Listeners<Int, Null<{}>> = new Listeners();
	public var onEnd:Listeners<Int, Null<{}>> = new Listeners();
	public var onComplete:Listeners<Int, Int> = new Listeners();
	public var onEvent:Listeners<Int, Event> = new Listeners();
	public var timeScale:Number = 1;

	public function new (data:AnimationStateData) {
		if (data == null) throw new ArgumentError("data cannot be null.");
		_data = data;
	}

	public function update (delta:Number) : Void {
		delta *= timeScale;
		for (i in 0..._tracks.length) {
			var current:TrackEntry = _tracks[i];
			if (current == null) continue;

			current.time += delta * current.timeScale;
			if (current.previous != null) {
				var previousDelta:Number = delta * current.previous.timeScale;
				current.previous.time += previousDelta;
				current.mixTime += previousDelta;
			}

			var next:TrackEntry = current.next;
			if (next != null) {
				next.time = current.lastTime - next.delay;
				if (next.time >= 0) setCurrent(i, next);
			} else {
				// End non-looping animation when it reaches its end time and there is no next entry.
				if (!current.loop && current.lastTime >= current.endTime) clearTrack(i);
			}
		}
	}

	public function apply (skeleton:Skeleton) : Void {
		for (i in 0..._tracks.length) {
			var current:TrackEntry = _tracks[i];
			if (current == null) continue;

			_events.length = 0;

			var time:Number = current.time;
			var lastTime:Number = current.lastTime;
			var endTime:Number = current.endTime;
			var loop:Bool = current.loop;
			if (!loop && time > endTime) time = endTime;

			var previous:TrackEntry = current.previous;
			if (previous == null) {
				if (current.mix == 1)
					current.animation.apply(skeleton, current.lastTime, time, loop, _events);
				else
					current.animation.mix(skeleton, current.lastTime, time, loop, _events, current.mix);
			} else {
				var previousTime:Number = previous.time;
				if (!previous.loop && previousTime > previous.endTime) previousTime = previous.endTime;
				previous.animation.apply(skeleton, previousTime, previousTime, previous.loop, null);

				var alpha:Number = current.mixTime / current.mixDuration * current.mix;
				if (alpha >= 1) {
					alpha = 1;
					current.previous = null;
				}
				current.animation.mix(skeleton, current.lastTime, time, loop, _events, alpha);
			}

			for (event in _events) {
				if (current.onEvent != null) current.onEvent(i, event);
				onEvent.invoke(i, event);
			}

			// Check if completed the animation or a loop iteration.
			if (loop ? (lastTime % endTime > time % endTime) : (lastTime < endTime && time >= endTime)) {
				var count:Int = (int)(time / endTime);
				if (current.onComplete != null) current.onComplete(i, count);
				onComplete.invoke(i, count);
			}

			current.lastTime = current.time;
		}
	}

	public function clearTracks () : Void {
		for (i in 0..._tracks.length)
			clearTrack(i);
		_tracks.length = 0;
	}

	public function clearTrack (trackIndex:Int) : Void {
		if (trackIndex >= _tracks.length) return;
		var current:TrackEntry = _tracks[trackIndex];
		if (current == null) return;

		if (current.onEnd != null) current.onEnd(trackIndex);
		onEnd.invoke(trackIndex, null);

		_tracks[trackIndex] = null;
	}

	private function expandToIndex (index:Int) : TrackEntry {
		if (index < _tracks.length) return _tracks[index];
		while (index >= _tracks.length)
			_tracks[_tracks.length] = null;
		return null;
	}

	private function setCurrent (index:Int, entry:TrackEntry) : Void {
		var current:TrackEntry = expandToIndex(index);
		if (current != null) {
			var previous:TrackEntry = current.previous;
			current.previous = null;

			if (current.onEnd != null) current.onEnd(index);
			onEnd.invoke(index, null);

			entry.mixDuration = _data.getMix(current.animation, entry.animation);
			if (entry.mixDuration > 0) {
				entry.mixTime = 0;
				// If a mix is in progress, mix from the closest animation.
				if (previous != null && current.mixTime / current.mixDuration < 0.5) {
					entry.previous = previous;
					previous = current;
				} else
					entry.previous = current;
			}
		}

		_tracks[index] = entry;

		if (entry.onStart != null) entry.onStart(index);
		onStart.invoke(index, null);
	}

	public function setAnimationByName (trackIndex:Int, animationName:String, loop:Bool) : TrackEntry {
		var animation:Animation = _data._skeletonData.findAnimation(animationName);
		if (animation == null) throw new ArgumentError("Animation not found: " + animationName);
		return setAnimation(trackIndex, animation, loop);
	}

	/** Set the current animation. Any queued animations are cleared. */
	public function setAnimation (trackIndex:Int, animation:Animation, loop:Bool) : TrackEntry {
		var entry:TrackEntry = new TrackEntry();
		entry.animation = animation;
		entry.loop = loop;
		entry.endTime = animation.duration;
		setCurrent(trackIndex, entry);
		return entry;
	}

	public function addAnimationByName (trackIndex:Int, animationName:String, loop:Bool, delay:Number) : TrackEntry {
		var animation:Animation = _data._skeletonData.findAnimation(animationName);
		if (animation == null) throw new ArgumentError("Animation not found: " + animationName);
		return addAnimation(trackIndex, animation, loop, delay);
	}

	/** Adds an animation to be played delay seconds after the current or last queued animation.
	 * @param delay May be <= 0 to use duration of previous animation minus any mix duration plus the negative delay. */
	public function addAnimation (trackIndex:Int, animation:Animation, loop:Bool, delay:Number) : TrackEntry {
		var entry:TrackEntry = new TrackEntry();
		entry.animation = animation;
		entry.loop = loop;
		entry.endTime = animation.duration;

		var last:TrackEntry = expandToIndex(trackIndex);
		if (last != null) {
			while (last.next != null)
				last = last.next;
			last.next = entry;
		} else
			_tracks[trackIndex] = entry;

		if (delay <= 0) {
			if (last != null)
				delay += last.endTime - _data.getMix(last.animation, animation);
			else
				delay = 0;
		}
		entry.delay = delay;

		return entry;
	}

	/** May be null. */
	public function getCurrent (trackIndex:Int) : TrackEntry {
		if (trackIndex >= _tracks.length) return null;
		return _tracks[trackIndex];
	}

	public function toString () : String {
		var buffer:String = "";
		for (entry in _tracks) {
			if (entry == null) continue;
			if (buffer.length > 0) buffer += ", ";
			buffer += entry.toString();
		}
		if (buffer.length == 0) return "<none>";
		return buffer;
	}
}