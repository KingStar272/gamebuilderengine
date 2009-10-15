package com.pblabs.rendering2D
{
    import com.pblabs.engine.PBE;
    import com.pblabs.engine.components.AnimatedComponent;
    import com.pblabs.engine.core.ObjectType;
    import com.pblabs.engine.core.ObjectTypeManager;
    import com.pblabs.engine.debug.Logger;
    import com.pblabs.rendering2D.ui.IUITarget;
    
    import flash.display.DisplayObject;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.geom.*;
    import flash.utils.Dictionary;
    
    /**
     * Basic Rendering2D scene; it is given a SceneView and some 
     * DisplayObjectRenderers, and makes sure that they are drawn. Extensible
     * for more complex rendering scenarios. Enforces sorting order, too.
     * 
     */
    public class DisplayObjectScene extends AnimatedComponent implements IScene2D
    {
        protected var _sceneView:IUITarget;
        protected var _sceneViewName:String = null;
        protected var _rootSprite:Sprite;
        protected var _layers:Array = [];
        protected var _renderers:Dictionary = new Dictionary(true);
        
        protected var _zoom:Number = 1;
        protected var _rootPosition:Point = new Point();
        protected var _rootRotation:Number = 0;
        protected var _rootTransform:Matrix = new Matrix();
        protected var _transformDirty:Boolean = true;
        protected var _currentWorldCenter:Point = new Point();

        public var minZoom:Number = .01;
        public var maxZoom:Number = 5;
        public var sceneAlignment:String = SceneAlignment.DEFAULT_ALIGNMENT;
        public var trackObject:DisplayObjectRenderer;
        
        public function DisplayObjectScene()
        {
            // Get ticked after all the renderers.
            updatePriority = -10;
            _rootSprite = generateRootSprite();
        }
        
        public function get layerCount():int
        {
            return _layers.length;
        }
        
        public function getLayer(index:int, allocateIfAbsent:Boolean = false):DisplayObjectSceneLayer
        {
            // Maybe it already exists.
            if(_layers[index])
                return _layers[index];
            
            if(allocateIfAbsent == false)
                return null;
            
            // Allocate the layer.
            _layers[index] = generateLayer(index);
            
            // Order the layers. This is suboptimal but we are probably not going
            // to be adding a lot of layers all the time.
            while(_rootSprite.numChildren)
                _rootSprite.removeChildAt(_rootSprite.numChildren-1);
            for(var i:int=0; i<layerCount; i++)
            {
                if (_layers[i])
                    _rootSprite.addChild(_layers[i]);
            }
            
            // Return new layer.
            return _layers[index];
        }
        
        public function invalidateRectangle(dirtyRect:Rectangle):void
        {
            // TODO: Propagate to relevant layers.
        }
        
        public function invalidate(dirtyRenderer:DisplayObjectRenderer):void
        {
            for each(var l:DisplayObjectSceneLayer in _layers)
            {
                if(l is ICachingLayer)
                    (l as ICachingLayer).invalidate(dirtyRenderer);
            }
        }
        
        protected function generateRootSprite():Sprite
        {
            var s:Sprite = new Sprite();
            
            //TODO: set any properties we want for our root host sprite
            
            return s;
        }
        
        protected function generateLayer(layerIndex:int):DisplayObjectSceneLayer
        {
            var l:DisplayObjectSceneLayer = new DisplayObjectSceneLayer();
            
            //TODO: set any properties we want for our layer.
            
            return l;
        }
        
        public function get sceneView():IUITarget
        {
            if(!_sceneView && _sceneViewName)
                sceneView = PBE.findChild(_sceneViewName) as IUITarget;
            
            return _sceneView;
        }
        
        public function set sceneView(value:IUITarget):void
        {
            if(_sceneView)
            {
                _sceneView.removeDisplayObject(_rootSprite);
            }
            
            _sceneView = value;
            
            if(_sceneView)
            {
                _sceneView.addDisplayObject(_rootSprite);
            }
        }
        
        
        public function set sceneViewName(value:String):void
        {
            _sceneViewName = value;
        }
        
        protected var _sceneViewBoundsCache:Rectangle = new Rectangle();
        
        protected var _tempPoint:Point = new Point();
        
        public function get sceneViewBounds():Rectangle
        {
            // What region of the scene are we currently viewing?
            SceneAlignment.calculate(_tempPoint, sceneAlignment, sceneView.width / zoom, sceneView.height / zoom);
            
            _sceneViewBoundsCache.x = -position.x - _tempPoint.x; 
            _sceneViewBoundsCache.y = -position.y - _tempPoint.y;
            _sceneViewBoundsCache.width = sceneView.width / zoom;
            _sceneViewBoundsCache.height = sceneView.height / zoom;
            
            return _sceneViewBoundsCache;
        }
        
        protected function sceneViewResized(event:Event) : void
        {
            _transformDirty = true;
        }
        
        public function add(dor:DisplayObjectRenderer):void
        {
            // Add to the appropriate layer.
            var layer:DisplayObjectSceneLayer = getLayer(dor.layerIndex, true);
            layer.add(dor);
            if (dor.displayObject)
                _renderers[dor.displayObject] = dor;
        }
        
        public function remove(dor:DisplayObjectRenderer):void
        {
            var layer:DisplayObjectSceneLayer = getLayer(dor.layerIndex, false);
            if(!layer)
                return;

            layer.remove(dor);
            if (dor.displayObject)
                delete _renderers[dor.displayObject];
        }
        
        public function transformWorldToScene(inPos:Point):Point
        {
            return inPos;
        }
        
        public function transformSceneToWorld(inPos:Point):Point
        {
            return inPos;
        }
        
        public function transformSceneToScreen(inPos:Point):Point
        {
            return _rootSprite.localToGlobal(inPos);
        }
        
        public function transformScreenToScene(inPos:Point):Point
        {
            return _rootSprite.globalToLocal(inPos);
        }
        
        public function transformWorldToScreen(inPos:Point):Point
        {
            return _rootSprite.localToGlobal(inPos);            
        }
        
        public function transformScreenToWorld(inPos:Point):Point
        {
            return _rootSprite.globalToLocal(inPos);            
        }
        
        public function getRenderersUnderPoint(screenPosition:Point, mask:ObjectType=null):Array
        {
            // Query normal DO hierarchy.
            var unfilteredResults:Array = _rootSprite.getObjectsUnderPoint(screenPosition);
            
            // TODO: rewrite to splice from unfilteredResults to avoid alloc?
            var results:Array = new Array();
            
            for each (var o:* in unfilteredResults)
            {
                var renderer:DisplayObjectRenderer = getRendererForDisplayObject(o);
                if (renderer 
                    && renderer.pointOccupied(screenPosition) 
                    && renderer.owner 
                    && (!mask || ObjectTypeManager.instance.doTypesOverlap(mask, renderer.objectMask)))
                    results.push(renderer.owner);
            }

            // Also give layers opportunity to return entities.
            var scenePosition:Point = transformScreenToScene(screenPosition);
            for each(var l:DisplayObjectSceneLayer in _layers)
            {
                if(l is ILayerMouseHandler)
                    (l as ILayerMouseHandler).getRenderersUnderPoint(scenePosition, mask, results);
            }
            
            return results;
        }
        
        protected function getRendererForDisplayObject(displayObject:DisplayObject):DisplayObjectRenderer
        {
            var current:DisplayObject = displayObject;
            
            // Walk up the display tree looking for a DO we know about.
            while (current)
            {
                // See if it's a DOR.
                var renderer:DisplayObjectRenderer = _renderers[current] as DisplayObjectRenderer;
                if (renderer)
                    return renderer;
                
                // If we get to a layer, we know we're done.
                if(renderer is DisplayObjectSceneLayer)
                    return null;
                
                // Go up the tree..
                current = current.parent;
            }
            
            // No match!
            return null;
        }

        public function updateTransform():void
        {
            if(_transformDirty == false)
                return;
            _transformDirty = false;

            // Update our transform, if required
            _rootTransform.identity();
            _rootTransform.translate(_rootPosition.x, _rootPosition.y);
            _rootTransform.scale(zoom, zoom);
            
            // Center it appropriately.
            SceneAlignment.calculate(_tempPoint, sceneAlignment, sceneView.width, sceneView.height);
            _rootTransform.translate(_tempPoint.x, _tempPoint.y);
            
            // Apply rotation.
            _rootTransform.rotate(_rootRotation);
            
            _rootSprite.transform.matrix = _rootTransform;
        }
        
        public override function onFrame(elapsed:Number) : void
        {
            if(!sceneView)
            {
                Logger.warn(this, "updateTransform", "sceneView is null, so we aren't rendering."); 
                return;
            }
            
            if(trackObject)
            {
                position = new Point(-(trackObject.sceneBounds.x + trackObject.sceneBounds.width * 0.5), 
                                     -(trackObject.sceneBounds.y + trackObject.sceneBounds.height * 0.5));
            }

            updateTransform();
            
            // Give layers a chance to sort and update.
            for each(var l:DisplayObjectSceneLayer in _layers)
                l.onRender();
        }
                
        public function setWorldCenter(pos:Point):void
        {
            if (!sceneView)
                throw new Error("sceneView not yet set. can't center the world.");
         
            position = transformWorldToScreen(pos);
        }
        
        public function screenPan(deltaX:int, deltaY:int):void
        {
            if(deltaX == 0 && deltaY == 0)
                return;
            
            // TODO: Take into account rotation so it's correct even when
            //       rotating.
            
            _rootPosition.x -= int(deltaX / _zoom);
            _rootPosition.y -= int(deltaY / _zoom);        
            _transformDirty = true;
        }
        
        public function get rotation():Number
        {
            return _rootRotation;
        }
        public function set rotation(value:Number):void
        {
            _rootRotation = value;
            _transformDirty = true;
        }
        
        public function get position():Point
        {
            return _rootPosition.clone();
        }
        
        public function set position(value:Point) : void
        {
            if (!value)
                return;
            
            var newX:int = int(value.x);
            var newY:int = int(value.y);
            
            if (_rootPosition.x == newX && _rootPosition.y == newY)
                return;
                
            _rootPosition.x = newX;
            _rootPosition.y = newY;
            _transformDirty = true;
        }
        
        public function get zoom():Number
        {
            return _zoom;
        }
        
        public function set zoom(value:Number):void
        {
            // Make sure our zoom level stays within the desired bounds
            value = Math.max(value, minZoom);
            value = Math.min(value, maxZoom);
            
            if (_zoom == value)
                return;
                
            _zoom = value;
            _transformDirty = true;
        }
        
        public function sortSpatials(array:Array):void
        {
            // Subclasses can set how things are sorted.
        }
    }
}