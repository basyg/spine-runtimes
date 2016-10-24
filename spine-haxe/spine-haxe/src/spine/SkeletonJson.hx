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
import spine.animation.PathConstraintMixTimeline;
import spine.animation.PathConstraintSpacingTimeline;
import spine.animation.PathConstraintPositionTimeline;
import spine.animation.TransformConstraintTimeline;
import spine.animation.ShearTimeline;
import spine.attachments.PathAttachment;
import spine.attachments.VertexAttachment;
import flash.utils.ByteArray;

import spine.animation.Animation;
import spine.animation.AttachmentTimeline;
import spine.animation.ColorTimeline;
import spine.animation.CurveTimeline;
import spine.animation.DrawOrderTimeline;
import spine.animation.EventTimeline;
import spine.animation.DeformTimeline;
import spine.animation.IkConstraintTimeline;
import spine.animation.RotateTimeline;
import spine.animation.ScaleTimeline;
import spine.animation.Timeline;
import spine.animation.TranslateTimeline;
import spine.attachments.Attachment;
import spine.attachments.AttachmentLoader;
import spine.attachments.AttachmentType;
import spine.attachments.BoundingBoxAttachment;
import spine.attachments.MeshAttachment;
import spine.attachments.RegionAttachment;

class SkeletonJson {
	public var attachmentLoader:AttachmentLoader;
	public var scale:Number = 1;
	private var linkedMeshes:Vector<LinkedMesh> = new Vector<LinkedMesh>();

	public function new (attachmentLoader:AttachmentLoader = null) {
		this.attachmentLoader = attachmentLoader;
	}

	/** @param object A String or ByteArray. */
	public function readSkeletonData (object:Dynamic, name:String = null) : SkeletonData {
		if (object == null) throw new ArgumentError("object cannot be null.");

		var root:TRoot;
		if ((object is String))
			root = haxe.Json.parse(String.safeCast(object));
		else if ((object is ByteArray))
			root = haxe.Json.parse(ByteArray.safeCast(object).readUTFBytes(ByteArray.safeCast(object).length));
		else if (Reflect.isObject(object))
			root = object;
		else
			throw new ArgumentError("object must be a String, ByteArray or Object.");

		var skeletonData:SkeletonData = new SkeletonData();
		skeletonData.name = name;

		// Skeleton.
		var skeletonMap:SpineMay<TSkeletonMap> = root.skeleton;
		if (skeletonMap.isSome) {
			skeletonData.hash = skeletonMap!.hash;
			skeletonData.version = skeletonMap!.spine;
			skeletonData.width = skeletonMap!.width.or(0);
			skeletonData.height = skeletonMap!.height.or(0);			
		}			

		// Bones.
		for (boneMap in root.bones) {
			var parent:BoneData = null;
			var parentName:SpineMay<String> = boneMap.parent;
			if (parentName.isSome) {
				parent = skeletonData.findBone(parentName!);
				if (parent == null) throw new Error("Parent bone not found: " + parentName);
			}
			var boneDataR:BoneData = new BoneData(skeletonData.bones.length, boneMap.name, parent);
			boneDataR.length = boneMap.length.or(0) * scale;
			boneDataR.x = boneMap.x.or(0) * scale;
			boneDataR.y = boneMap.y.or(0) * scale;
			boneDataR.rotation = boneMap.rotation.or(0);
			boneDataR.scaleX = boneMap.scaleX.or(1);
			boneDataR.scaleY = boneMap.scaleY.or(1);
			boneDataR.shearX = boneMap.shearX.or(0);
			boneDataR.shearY = boneMap.shearY.or(0);
			boneDataR.inheritRotation = boneMap.inheritRotation.or(true);
			boneDataR.inheritScale = boneMap.inheritScale.or(true);			
			skeletonData.bones.push(boneDataR);
		}
		
		// Slots.
		for (slotMap in root.slots) {
			var slotName:String = slotMap.name;
			var boneName:String = slotMap.bone;
			var bone:BoneData = skeletonData.findBone(boneName);
			if (bone == null) throw new Error("Slot bone not found: " + boneName);
			var slotData:SlotData = new SlotData(skeletonData.slots.length, slotName, bone);

			var color:SpineMay<String> = slotMap.color;
			if (color.isSome) {
				slotData.r = toColor(color!, 0);
				slotData.g = toColor(color!, 1);
				slotData.b = toColor(color!, 2);
				slotData.a = toColor(color!, 3);
			}

			slotData.attachmentName = slotMap.attachment;
			slotData.blendMode = BlendMode.getSpineEnum(slotMap.blend.or("normal"));
			skeletonData.slots.push(slotData);
		}

		// IK constraints.
		for (constraintMap in root.ik.values()) {
			var ikConstraintData:IkConstraintData = new IkConstraintData(constraintMap.name);

			for (boneName in constraintMap.bones) {
				var bone:BoneData = skeletonData.findBone(boneName);
				if (bone == null) throw new Error("IK constraint bone not found: " + boneName);
				ikConstraintData.bones.push(bone);
			}

			ikConstraintData.target = skeletonData.findBone(constraintMap.target);
			if (ikConstraintData.target == null) throw new Error("Target bone not found: " + constraintMap.target);

			ikConstraintData.bendDirection = constraintMap.bendPositive.or(false) ? 1 : -1;
			ikConstraintData.mix = constraintMap.mix.or(1);

			skeletonData.ikConstraints.push(ikConstraintData);
		}

		// Transform constraints.
		for (constraintMap in root.transform.values()) {
			var transformConstraintData:TransformConstraintData = new TransformConstraintData(constraintMap.name);

			for (boneName in constraintMap.bones) {
				var bone:BoneData = skeletonData.findBone(boneName);
				if (bone == null) throw new Error("Transform constraint bone not found: " + boneName);
				transformConstraintData.bones.push(bone);
			}
		
			transformConstraintData.target = skeletonData.findBone(constraintMap.target);
			if (transformConstraintData.target == null) throw new Error("Target bone not found: " + constraintMap.target);
			
			transformConstraintData.offsetRotation = constraintMap.rotation.or(0);
			transformConstraintData.offsetX = constraintMap.x.or(0) * scale;
			transformConstraintData.offsetY = constraintMap.y.or(0) * scale;
			transformConstraintData.offsetScaleX = constraintMap.scaleX.or(0);
			transformConstraintData.offsetScaleY = constraintMap.scaleY.or(0);
			transformConstraintData.offsetShearY = constraintMap.shearY.or(0);
			
			transformConstraintData.rotateMix = constraintMap.rotateMix.or(1);
			transformConstraintData.translateMix = constraintMap.translateMix.or(1);
			transformConstraintData.scaleMix = constraintMap.scaleMix.or(1);
			transformConstraintData.shearMix = constraintMap.shearMix.or(1);

			skeletonData.transformConstraints.push(transformConstraintData);
		}
		
		// Path constraints.
		for (constraintMap in root.path.values()) {
			var pathConstraintData:PathConstraintData = new PathConstraintData(constraintMap.name);

			for (boneName in constraintMap.bones) {
				var bone:BoneData = skeletonData.findBone(boneName);
				if (bone == null) throw new Error("Path constraint bone not found: " + boneName);
				pathConstraintData.bones.push(bone);
			}
		
			pathConstraintData.target = skeletonData.findSlot(constraintMap.target);
			if (pathConstraintData.target == null) throw new Error("Path target slot not found: " + constraintMap.target);

			pathConstraintData.positionMode = PositionMode.getSpineEnum(constraintMap.positionMode.or("percent"));
			pathConstraintData.spacingMode = SpacingMode.getSpineEnum(constraintMap.spacingMode.or("length"));
			pathConstraintData.rotateMode = RotateMode.getSpineEnum(constraintMap.rotateMode.or("tangent"));
			pathConstraintData.offsetRotation = constraintMap.rotation.or(0);
			pathConstraintData.position = constraintMap.position.or(0);
			if (pathConstraintData.positionMode == PositionMode.fixed) pathConstraintData.position *= scale;
			pathConstraintData.spacing = constraintMap.spacing.or(0);
			if (pathConstraintData.spacingMode == SpacingMode.length || pathConstraintData.spacingMode == SpacingMode.fixed) pathConstraintData.spacing *= scale;
			pathConstraintData.rotateMix = constraintMap.rotateMix.or(1);
			pathConstraintData.translateMix = constraintMap.translateMix.or(1);

			skeletonData.pathConstraints.push(pathConstraintData);
		}

		// Skins.
		var skins:DynamicMap<TSkinMap> = root.skins;
		for (skinName in skins.keys()) {
			var skinMap:TSkinMap = skins[skinName];
			var skin:Skin = new Skin(skinName);
			for (slotName in skinMap.keys()) {
				var slotIndex:Int = skeletonData.findSlotIndex(slotName);
				var slotEntry:TSlotEntry = skinMap[slotName];
				for (attachmentName in slotEntry.keys()) {
					var attachment:Attachment = readAttachment(slotEntry[attachmentName], skin, slotIndex, attachmentName);
					if (attachment != null)
						skin.addAttachment(slotIndex, attachmentName, attachment);
				}
			}
			skeletonData.skins[skeletonData.skins.length] = skin;
			if (skin.name == "default")
				skeletonData.defaultSkin = skin;
		}

		// Linked meshes.
		var linkedMeshes:Vector<LinkedMesh> = this.linkedMeshes;
		for (linkedMesh in linkedMeshes) {
			var parentSkin:Skin = linkedMesh.skin == null ? skeletonData.defaultSkin : skeletonData.findSkin(linkedMesh.skin);
			if (parentSkin == null) throw new Error("Skin not found: " + linkedMesh.skin);
			var parentMesh:Attachment = parentSkin.getAttachment(linkedMesh.slotIndex, linkedMesh.parent);
			if (parentMesh == null) throw new Error("Parent mesh not found: " + linkedMesh.parent);
			linkedMesh.mesh.parentMesh = MeshAttachment.safeCast(parentMesh);
			linkedMesh.mesh.updateUVs();
		}
		linkedMeshes.length = 0;

		// Events.
		var events:SpineMay<DynamicMap<TEventMap>> = root.events;
		if (events.isSome) {
			for (eventName in events!.keys()) {
				var eventMap:TEventMap = events![eventName];
				var eventData:EventData = new EventData(eventName);
				eventData.intValue = eventMap.int.or(0);
				eventData.floatValue = eventMap.float.or(0);
				eventData.stringValue = eventMap.string.or(null);
				skeletonData.events.push(eventData);
			}
		}

		// Animations.
		var animations:DynamicMap<TAnimationMap> = root.animations;
		for (animationName in animations.keys())
			readAnimation(animations[animationName], animationName, skeletonData);

		return skeletonData;
	}

	private function readAttachment (map:TAttachment, skin:Skin, slotIndex:Int, name:String) : Attachment {
		name = map.name.or(name);

		var typeName:String = map.type.or("region");		
		var type:AttachmentType = AttachmentType.getSpineEnum(typeName);		

		var scale:Number = this.scale;
		switch (type) {
			case AttachmentType.region:
				var region:RegionAttachment = attachmentLoader.newRegionAttachment(skin, name, map.path.or(name));
				if (region == null) return null;
				region.path = map.path.or(name);
				region.x = map.x.or(0) * scale;
				region.y = map.y.or(0) * scale;
				region.scaleX = map.scaleX.or(1);
				region.scaleY = map.scaleY.or(1);
				region.rotation = map.rotation.or(0);
				region.width = map.width.or(0) * scale;
				region.height = map.height.or(0) * scale;
				var color:SpineMay<String> = map.color;
				if (color.isSome) {
					region.r = toColor(color!, 0);
					region.g = toColor(color!, 1);
					region.b = toColor(color!, 2);
					region.a = toColor(color!, 3);
				}
				region.updateOffset();
				return region;
			case AttachmentType.mesh | AttachmentType.linkedmesh:
				var mesh:MeshAttachment = attachmentLoader.newMeshAttachment(skin, name, map.path.or(name));
				if (mesh == null) return null;
				mesh.path = map.path.or(name);

				var color:SpineMay<String> = map.color;
				if (color.isSome) {
					mesh.r = toColor(color!, 0);
					mesh.g = toColor(color!, 1);
					mesh.b = toColor(color!, 2);
					mesh.a = toColor(color!, 3);
				}

				mesh.width = map.width.or(0) * scale;
				mesh.height = map.height.or(0) * scale;

				if (map.parent.isSome) {
					mesh.inheritDeform = map.deform.or(true);
					linkedMeshes.push(new LinkedMesh(mesh, map.skin!, slotIndex, map.parent!));
					return mesh;
				}
				
				var uvs:Vector<Number> = getFloatArray(map.uvs!, 1);
				readVertices(map, mesh, uvs.length);			
				mesh.triangles = getUintArray(map.triangles!);	
				mesh.regionUVs = uvs;									
				mesh.updateUVs();

				mesh.hullLength = int(map.hull.or(0)) * 2;
				if (map.edges.isSome) mesh.edges = getIntArray(map.edges!);
				return mesh;
			case AttachmentType.boundingbox:
				var box:BoundingBoxAttachment = attachmentLoader.newBoundingBoxAttachment(skin, name);
				if (box == null) return null;
				readVertices(map, box, int(map.vertexCount!) << 1);								
				return box;
			case AttachmentType.path:
				var path:PathAttachment = attachmentLoader.newPathAttachment(skin, name);
				if (path == null) return null;
				path.closed = map.closed.or(false);
				path.constantSpeed = map.constantSpeed.or(true);
				
				var vertexCount:Int = int(map.vertexCount!);
				readVertices(map, path, vertexCount << 1);
				
				var lengths:Vector<Number> = new Vector<Number>();							
				for (curves in map.lengths!) {
					lengths.push(curves * scale);
				}
				path.lengths = lengths;				
				return path;
		}

		return null;
	}
	
	private function readVertices(map:TAttachment, attachment:VertexAttachment, verticesLength:Int) : Void {
		attachment.worldVerticesLength = verticesLength;
		var vertices:Vector<Number> = getFloatArray(map.vertices!, 1);
		if (verticesLength == vertices.length) {
			if (scale != 1) {
				for (i in 0...vertices.length) {
					vertices[i] *= scale;
				}
			}
			attachment.vertices = vertices;
			return;
		}
		
		var weights:Vector<Number> = new Vector<Number>(verticesLength * 3 * 3);
		weights.length = 0;
		var bones:Vector<Int> = new Vector<Int>(verticesLength * 3);
		bones.length = 0;
		var i:Int = 0, n:Int = vertices.length;	while (i < n) {
			var boneCount:Int = int(vertices[i++]);
			bones.push(boneCount);
			var nn:Int = i + boneCount * 4; while (i < nn) {
				bones.push(int(vertices[i]));
				weights.push(vertices[i + 1] * scale);
				weights.push(vertices[i + 2] * scale);
				weights.push(vertices[i + 3]);
				i += 4;
			}
		}
		attachment.bones = bones;
		attachment.vertices = weights;
	}

	private function readAnimation (map:TAnimationMap, name:String, skeletonData:SkeletonData) : Void {
		var scale:Number = this.scale;
		var timelines:Vector<Timeline> = new Vector<Timeline>();
		var duration:Number = 0;

		var slotMap:TAnimationSlotMap, slotIndex:Int, slotName:String;
		var values:TTimeline, valueMap:TValueMap, frameIndex:Int;
		var i:Int;
		var timelineName:String;

		var slots:DynamicMap<TAnimationSlotMap> = map.slots;
		for (slotName in slots.keys()) {
			slotMap = slots[slotName];
			slotIndex = skeletonData.findSlotIndex(slotName);

			for (timelineName in slotMap.keys()) {
				values = slotMap[timelineName];
				if (timelineName == "color") {
					var colorTimeline:ColorTimeline = new ColorTimeline(values.length);
					colorTimeline.slotIndex = slotIndex;

					frameIndex = 0;
					for (valueMap in values) {
						var color:String = valueMap.color;
						var r:Number = toColor(color, 0);
						var g:Number = toColor(color, 1);
						var b:Number = toColor(color, 2);
						var a:Number = toColor(color, 3);
						colorTimeline.setFrame(frameIndex, valueMap.time, r, g, b, a);
						readCurve(valueMap.curve, colorTimeline, frameIndex);
						frameIndex++;
					}
					timelines[timelines.length] = colorTimeline;
					duration = Math.max(duration, colorTimeline.frames[(colorTimeline.frameCount - 1) * ColorTimeline.ENTRIES]);
				} else if (timelineName == "attachment") {
					var attachmentTimeline:AttachmentTimeline = new AttachmentTimeline(values.length);
					attachmentTimeline.slotIndex = slotIndex;

					frameIndex = 0;
					for (valueMap in values)
						attachmentTimeline.setFrame(frameIndex++, valueMap.time, valueMap.name);
					timelines[timelines.length] = attachmentTimeline;
					duration = Math.max(duration, attachmentTimeline.frames[attachmentTimeline.frameCount - 1]);
				} else
					throw new Error("Invalid timeline type for a slot: " + timelineName + " (" + slotName + ")");
			}
		}

		var bones:DynamicMap<TAnimationBone> = map.bones;
		for (boneName in bones.keys()) {
			var boneIndex:Int = skeletonData.findBoneIndex(boneName);
			if (boneIndex == -1) throw new Error("Bone not found: " + boneName);
			var boneMap:TAnimationBone = bones[boneName];

			for (timelineName in boneMap.keys()) {
				values = boneMap[timelineName];
				if (timelineName == "rotate") {
					var rotateTimeline:RotateTimeline = new RotateTimeline(values.length);
					rotateTimeline.boneIndex = boneIndex;

					frameIndex = 0;
					for (valueMap in values) {
						rotateTimeline.setFrame(frameIndex, valueMap.time, valueMap.angle);
						readCurve(valueMap.curve, rotateTimeline, frameIndex);
						frameIndex++;
					}
					timelines[timelines.length] = rotateTimeline;
					duration = Math.max(duration, rotateTimeline.frames[(rotateTimeline.frameCount - 1) * RotateTimeline.ENTRIES]);
				} else if (timelineName == "translate" || timelineName == "scale" || timelineName == "shear") {
					var translateTimeline:TranslateTimeline;
					var timelineScale:Number = 1;
					if (timelineName == "scale")
						translateTimeline = new ScaleTimeline(values.length);
					else if (timelineName == "shear")
						translateTimeline = new ShearTimeline(values.length);
					else {
						translateTimeline = new TranslateTimeline(values.length);
						timelineScale = scale;
					}
					translateTimeline.boneIndex = boneIndex;

					frameIndex = 0;
					for (valueMap in values) {
						var x:Number = valueMap.x.or(0) * timelineScale;
						var y:Number = valueMap.y.or(0) * timelineScale;
						translateTimeline.setFrame(frameIndex, valueMap.time, x, y);
						readCurve(valueMap.curve, translateTimeline, frameIndex);
						frameIndex++;
					}
					timelines[timelines.length] = translateTimeline;
					duration = Math.max(duration, translateTimeline.frames[(translateTimeline.frameCount - 1) * TranslateTimeline.ENTRIES]);
				} else
					throw new Error("Invalid timeline type for a bone: " + timelineName + " (" + boneName + ")");
			}
		}

		var ikMap:DynamicMap<TAnimationConstraint> = map.ik;
		for (ikConstraintName in ikMap.keys()) {
			var ikConstraint:IkConstraintData = skeletonData.findIkConstraint(ikConstraintName);
			values = ikMap[ikConstraintName];
			var ikTimeline:IkConstraintTimeline = new IkConstraintTimeline(values.length);
			ikTimeline.ikConstraintIndex = skeletonData.ikConstraints.indexOf(ikConstraint);
			frameIndex = 0;
			for (valueMap in values) {
				var mix:Number = valueMap.mix.or(1);
				var bendDirection:Int = valueMap.bendPositive.or(false) ? 1 : -1;
				ikTimeline.setFrame(frameIndex, valueMap.time, mix, bendDirection);
				readCurve(valueMap.curve, ikTimeline, frameIndex);
				frameIndex++;
			}
			timelines[timelines.length] = ikTimeline;
			duration = Math.max(duration, ikTimeline.frames[(ikTimeline.frameCount - 1) * IkConstraintTimeline.ENTRIES]);
		}
		
		var transformMap:DynamicMap<TAnimationConstraint> = map.transform;
		for (transformName in transformMap.keys()) {
			var transformConstraint:TransformConstraintData = skeletonData.findTransformConstraint(transformName);
			values = transformMap[transformName];
			var transformTimeline:TransformConstraintTimeline = new TransformConstraintTimeline(values.length);
			transformTimeline.transformConstraintIndex = skeletonData.transformConstraints.indexOf(transformConstraint);
			frameIndex = 0;
			for (valueMap in values) {
				var rotateMix:Number = valueMap.rotateMix.or(1);
				var translateMix:Number = valueMap.translateMix.or(1);
				var scaleMix:Number = valueMap.scaleMix.or(1);
				var shearMix:Number = valueMap.shearMix.or(1);
				transformTimeline.setFrame(frameIndex, valueMap.time, rotateMix, translateMix, scaleMix, shearMix);
				readCurve(valueMap.curve, transformTimeline, frameIndex);
				frameIndex++;
			}
			timelines.push(transformTimeline);
			duration = Math.max(duration, transformTimeline.frames[(transformTimeline.frameCount - 1) * TransformConstraintTimeline.ENTRIES]);
		}
				
		// Path constraint timelines.
		var paths:DynamicMap<TPathMap> = map.paths;
		for (pathName in paths.keys()) {
			var index:Int = skeletonData.findPathConstraintIndex(pathName);
			if (index == -1) throw new Error("Path constraint not found: " + pathName);
			var data:PathConstraintData = skeletonData.pathConstraints[index];
			
			var pathMap:TPathMap = paths[pathName];
			for (timelineName in pathMap.keys()) {
				values = pathMap[timelineName];
				
				if (timelineName == "position" || timelineName == "spacing") {
					var pathTimeline:PathConstraintPositionTimeline;
					var timelineScale:Number = 1;
					if (timelineName == "spacing") {
						pathTimeline = new PathConstraintSpacingTimeline(values.length);
						if (data.spacingMode == SpacingMode.length || data.spacingMode == SpacingMode.fixed) timelineScale = scale;
					} else {
						pathTimeline = new PathConstraintPositionTimeline(values.length);
						if (data.positionMode == PositionMode.fixed) timelineScale = scale;
					}
					pathTimeline.pathConstraintIndex = index;
					frameIndex = 0;
					for (valueMap in values) {
						var value:Number = (valueMap:DynamicMap<SpineMay<Number>>)[timelineName].or(0);
						pathTimeline.setFrame(frameIndex, valueMap.time, value * timelineScale);
						readCurve(valueMap.curve, pathTimeline, frameIndex);
						frameIndex++;
					}
					timelines.push(pathTimeline);
					duration = Math.max(duration,
						pathTimeline.frames[(pathTimeline.frameCount - 1) * PathConstraintPositionTimeline.ENTRIES]);
				} else if (timelineName == "mix") {
					var pathMixTimeline:PathConstraintMixTimeline = new PathConstraintMixTimeline(values.length);
					pathMixTimeline.pathConstraintIndex = index;
					frameIndex = 0;
					for (valueMap in values) {
						var rotateMix:Number = valueMap.rotateMix.or(1);
						var translateMix:Number = valueMap.translateMix.or(1);
						pathMixTimeline.setFrame(frameIndex, valueMap.time, rotateMix, translateMix);
						readCurve(valueMap.curve, pathMixTimeline, frameIndex);
						frameIndex++;
					}
					timelines.push(pathMixTimeline);
					duration = Math.max(duration,
						pathMixTimeline.frames[(pathMixTimeline.frameCount - 1) * PathConstraintMixTimeline.ENTRIES]);
				}
			}
		}
		
		var deformMap:DynamicMap<TDeformSlotMap> = map.deform;
		for (skinName in deformMap.keys()) {
			var skin:Skin = skeletonData.findSkin(skinName);
			var slotMap:TDeformSlotMap = deformMap[skinName];
			for (slotName in slotMap.keys()) {
				slotIndex = skeletonData.findSlotIndex(slotName);
				var timelineMap:TDeformTimeline = slotMap[slotName];
				for (timelineName in timelineMap.keys()) {
					values = timelineMap[timelineName];

					var attachment:VertexAttachment = Std.instance(skin.getAttachment(slotIndex, timelineName), VertexAttachment);
					if (attachment == null) throw new Error("Deform attachment not found: " + timelineName);
					var weighted:Bool = attachment.bones != null;
					var vertices:Vector<Number> = attachment.vertices;
					var deformLength:Int = weighted ? int(vertices.length / 3) * 2 : vertices.length;

					var deformTimeline:DeformTimeline = new DeformTimeline(values.length);
					deformTimeline.slotIndex = slotIndex;
					deformTimeline.attachment = attachment;

					frameIndex = 0;
					for (valueMap in values) {
						var deform:Vector<Number>;
						var verticesValue:SpineMay<Array<Number>> = valueMap.vertices;
						if (verticesValue.isNull)
							deform = weighted ? new Vector<Number>(deformLength, true) : vertices;
						else {
							deform = new Vector<Number>(deformLength, true);
							var start:Int = valueMap.offset.or(0);
							var temp:Vector<Number> = getFloatArray(valueMap.vertices!, 1);
							for (i in 0...temp.length) {
								deform[start + i] = temp[i];
							}							
							if (scale != 1) {
								for (i in start...(start + temp.length))
									deform[i] *= scale;
							}
							if (!weighted) {
								for (i in 0...deformLength)
									deform[i] += vertices[i];
							}
						}

						deformTimeline.setFrame(frameIndex, valueMap.time, deform);
						readCurve(valueMap.curve, deformTimeline, frameIndex);
						frameIndex++;
					}
					timelines[timelines.length] = deformTimeline;
					duration = Math.max(duration, deformTimeline.frames[deformTimeline.frameCount - 1]);
				}
			}
		}

		var drawOrderValues:SpineMay<Array<TDrawOrderMap>> = map.drawOrder;
		if (drawOrderValues.isNull) drawOrderValues = map.draworder;
		if (drawOrderValues.isSome) {
			var drawOrderTimeline:DrawOrderTimeline = new DrawOrderTimeline(drawOrderValues!.length);
			var slotCount:Int = skeletonData.slots.length;
			frameIndex = 0;
			for (drawOrderMap in drawOrderValues!) {
				var drawOrder:Vector<Int> = null;
				if (drawOrderMap.offsets.isSome) {
					drawOrder = new Vector<Int>(slotCount);
					var i:Int = slotCount - 1; while (i >= 0) {
						drawOrder[i] = -1;
						i--;
					}
					var offsets:Array<TOffsetMap> = drawOrderMap.offsets!;
					var unchanged:Vector<Int> = new Vector<Int>(slotCount - offsets.length);
					var originalIndex:Int = 0, unchangedIndex:Int = 0;
					for (offsetMap in offsets) {
						slotIndex = skeletonData.findSlotIndex(offsetMap.slot);
						if (slotIndex == -1) throw new Error("Slot not found: " + offsetMap.slot);
						// Collect unchanged items.
						while (originalIndex != slotIndex)
							unchanged[unchangedIndex++] = originalIndex++;
						// Set changed items.
						drawOrder[originalIndex + offsetMap.offset] = originalIndex++;
					}
					// Collect remaining unchanged items.
					while (originalIndex < slotCount)
						unchanged[unchangedIndex++] = originalIndex++;
					// Fill in unchanged items.
					var i:Int = slotCount - 1; while (i >= 0) {
						if (drawOrder[i] == -1) drawOrder[i] = unchanged[--unchangedIndex];
						i--;
					}
				}
				drawOrderTimeline.setFrame(frameIndex++, drawOrderMap.time, drawOrder);
			}
			timelines[timelines.length] = drawOrderTimeline;
			duration = Math.max(duration, drawOrderTimeline.frames[drawOrderTimeline.frameCount - 1]);
		}

		var eventsMap:SpineMay<Array<TAnimationEventMap>> = map.events;
		if (eventsMap.isSome) {
			var eventsMap:Array<TAnimationEventMap> = eventsMap!;
			var eventTimeline:EventTimeline = new EventTimeline(eventsMap.length);
			frameIndex = 0;
			for (eventMap in eventsMap) {
				var eventData:EventData = skeletonData.findEvent(eventMap.name);
				if (eventData == null) throw new Error("Event not found: " + eventMap.name);
				var event:Event = new Event(eventMap.time, eventData);
				event.intValue = eventMap.int.or(eventData.intValue);
				event.floatValue = eventMap.float.or(eventData.floatValue);
				event.stringValue = eventMap.string.or(eventData.stringValue);
				eventTimeline.setFrame(frameIndex++, event);
			}
			timelines[timelines.length] = eventTimeline;
			duration = Math.max(duration, eventTimeline.frames[eventTimeline.frameCount - 1]);
		}

		skeletonData.animations[skeletonData.animations.length] = new Animation(name, timelines, duration);
	}

	static private function readCurve (curve:SpineMay<Dynamic>, timeline:CurveTimeline, frameIndex:Int) : Void {
		if (curve.isNull) return;
		var curve:Dynamic = curve!;
		if ((curve is String) && String.safeCast(curve) == "stepped")
			timeline.setStepped(frameIndex);
		else if ((curve is TNumberArray)) {
			var curve:Array<Number> = curve;
			timeline.setCurve(frameIndex, curve[0], curve[1], curve[2], curve[3]);
		}
	}

	static private function toColor (hexString:String, colorIndex:Int) : Number {
		if (hexString.length != 8) throw new ArgumentError("Color hexidecimal length must be 8, recieved: " + hexString);
		return parseInt('0x' + hexString.substring(colorIndex * 2, colorIndex * 2 + 2)) / 255;
	}

	static private function getFloatArray (list:Array<Number>, scale:Number) : Vector<Number> {
		var values:Vector<Number> = new Vector<Number>(list.length, true);
		var i:Int = 0, n:Int = list.length;
		if (scale == 1) {
			while (i < n) {
				values[i] = list[i];
				i++;
			}
		} else {
			while (i < n) {
				values[i] = list[i] * scale;
				i++;
			}
		}
		return values;
	}

	static private function getIntArray (list:Array<Int>) : Vector<Int> {
		var values:Vector<Int> = new Vector<Int>(list.length, true);
		for (i in 0...list.length)
			values[i] = int(list[i]);
		return values;
	}

	static private function getUintArray (list:Array<UInt>) : Vector<UInt> {
		var values:Vector<UInt> = new Vector<UInt>(list.length, true);
		for (i in 0...list.length)
			values[i] = int(list[i]);
		return values;
	}
}

private class LinkedMesh {
	@:allow(spine) var parent:String; @:allow(spine) var skin:String;
	@:allow(spine) var slotIndex:Int;
	@:allow(spine) var mesh:MeshAttachment;

	public function new (mesh:MeshAttachment, skin:String, slotIndex:Int, parent:String) {
		this.mesh = mesh;
		this.skin = skin;
		this.slotIndex = slotIndex;
		this.parent = parent;
	}
}

abstract SpineMay<T>(Null<T>) from Null<T> {
    public var isNull(get, never):Bool; inline function get_isNull():Bool return this == null;
    public var isSome(get, never):Bool; inline function get_isSome():Bool return this != null;

    @:op(A!)
    public inline function unwrap():Null<T> return this == null ? throw 'cant unwrap from null' : this;

	public inline function or(defaultValue:T):T return this == null ? defaultValue : this;
}

private typedef TRoot = {
	skeleton: SpineMay<TSkeletonMap>,
	bones: Array<TBoneMap>,
	slots: Array<TSlotMap>,
	ik: DynamicMap<TIkConstraintMap>,
	transform: DynamicMap<TTransformConstraintMap>,
	path: DynamicMap<TPathConstraintMap>,
	skins: DynamicMap<TSkinMap>,
	events: SpineMay<DynamicMap<TEventMap>>,
	animations:DynamicMap<TAnimationMap>,
}

private typedef TSkeletonMap = {
	hash: String,
	spine: String,
	width: SpineMay<Number>,
	height: SpineMay<Number>,
}

private typedef TBoneMap = {
	parent: SpineMay<String>,
	name: String,
	length: SpineMay<Number>,
	x: SpineMay<Number>,
	y: SpineMay<Number>,
	rotation: SpineMay<Number>,
	scaleX: SpineMay<Number>,
	scaleY: SpineMay<Number>,
	shearX: SpineMay<Number>,
	shearY: SpineMay<Number>,
	inheritRotation: SpineMay<Bool>,
	inheritScale: SpineMay<Bool>,
}

private typedef TSlotMap = {
	name: String,
	bone: String,
	color: SpineMay<String>,
	attachment: String,
	blend: SpineMay<String>,
}

private typedef TIkConstraintMap = {
	name: String,
	bones: Array<String>,
	target: String,
	bendPositive: SpineMay<Bool>,
	mix: SpineMay<Number>,
}

private typedef TTransformConstraintMap = {
	name: String,
	bones: Array<String>,
	target: String,
	rotation: SpineMay<Number>,
	x: SpineMay<Number>,
	y: SpineMay<Number>,
	scaleX: SpineMay<Number>,
	scaleY: SpineMay<Number>,
	shearY: SpineMay<Number>,
	rotateMix: SpineMay<Number>,
	translateMix: SpineMay<Number>,
	scaleMix: SpineMay<Number>,
	shearMix: SpineMay<Number>,
}

private typedef TPathConstraintMap = {
	name: String,
	bones: Array<String>,
	target: String,
	positionMode: SpineMay<String>,
	spacingMode: SpineMay<String>,
	rotateMode: SpineMay<String>,
	rotation: SpineMay<Number>,
	position: SpineMay<Number>,
	spacing: SpineMay<Number>,
	rotateMix: SpineMay<Number>,
	translateMix: SpineMay<Number>,
}

private typedef TSkinMap = DynamicMap<TSlotEntry>;

private typedef TSlotEntry = DynamicMap<TAttachment>;

private typedef TAttachment = {
	name: SpineMay<String>,
	type: SpineMay<String>,
	path: SpineMay<String>,
	x: SpineMay<Number>,
	y: SpineMay<Number>,
	scaleX: SpineMay<Number>,
	scaleY: SpineMay<Number>,
	rotation: SpineMay<Number>,
	width: SpineMay<Number>,
	height: SpineMay<Number>,
	color: SpineMay<String>,
	parent: SpineMay<String>,
	deform: SpineMay<Bool>,
	skin: SpineMay<String>,
	uvs: SpineMay<Array<Number>>,
	triangles: SpineMay<Array<UInt>>,
	hull: SpineMay<Int>,
	edges: SpineMay<Array<Int>>,
	vertexCount: SpineMay<Int>,
	closed: SpineMay<Bool>,
	constantSpeed: SpineMay<Bool>,
	lengths: SpineMay<Array<Number>>,
	vertices: SpineMay<Array<Number>>,
}

private typedef TEventMap = {
	int: SpineMay<Int>,
	float: SpineMay<Number>,
	string: SpineMay<String>,
}

private typedef TAnimationMap = {
	slots: DynamicMap<TAnimationSlotMap>,
	lengths: Array<Number>,
	bones: DynamicMap<TAnimationBone>,
	ik: DynamicMap<TAnimationConstraint>,
	transform: DynamicMap<TAnimationConstraint>,
	paths: DynamicMap<TPathMap>,
	deform: DynamicMap<TDeformSlotMap>,
	drawOrder: SpineMay<Array<TDrawOrderMap>>,
	draworder: SpineMay<Array<TDrawOrderMap>>,
	events: SpineMay<Array<TAnimationEventMap>>,
}

private typedef TTimeline = Array<TValueMap>;

private typedef TValueMap = {
	color: String,
	time: Number,
	curve: SpineMay<Dynamic>,
	name: String,
	angle: Number,
	x: SpineMay<Number>,
	y: SpineMay<Number>,
	mix: SpineMay<Number>,
	bendPositive: SpineMay<Bool>,
	rotateMix: SpineMay<Number>,
	translateMix: SpineMay<Number>,
	scaleMix: SpineMay<Number>,
	shearMix: SpineMay<Number>,
	vertices: SpineMay<Array<Number>>,
	offset: SpineMay<Int>,
}

private typedef TAnimationSlotMap = DynamicMap<TTimeline>;

private typedef TAnimationBone = DynamicMap<TTimeline>;

private typedef TAnimationConstraint = DynamicMap<TTimeline>;

private typedef TPathMap = DynamicMap<TAnimationConstraint>;

private typedef TDeformSlotMap = DynamicMap<TDeformTimeline>;

private typedef TDeformTimeline = DynamicMap<TTimeline>;

private typedef TDrawOrderMap = {
	offsets: SpineMay<Array<TOffsetMap>>,
	time: Number,
}

private typedef TOffsetMap = {
	slot: String,
	offset: Int,
}

private typedef TAnimationEventMap = {
	name: String,
	time: Number,
	int: SpineMay<Int>,
	float: SpineMay<Number>,
	string: SpineMay<String>,
}

private typedef TNumberArray = Array<Number>;
