package com.pblabs.triggers.actions
{
	import com.pblabs.engine.scripting.ExpressionReference;
	import com.pblabs.triggers.ITriggerComponent;
	
	public class BaseAction implements IAction
	{
		private var _destroyed : Boolean = false;
		private var _stoped:Boolean = false;

		public function BaseAction()
		{
		}
		
		public function execute():*
		{
			return null;
		}
		
		public function updateGlobalExpressionProperty():void { }
		public function clearGlobalExpressionProperty():void { }
		
		public function stop():void { _stoped = true; }
		
		public function destroy():void
		{
			_owner = null;
			_destroyed = true;
		}
		
		public function getExpressionValue(expression : ExpressionReference):*
		{
			return ExpressionReference.getExpressionValue(expression, _owner.owner);
		}

		protected var _owner : ITriggerComponent;
		[EditorData(ignore="true")]
		public function get owner():ITriggerComponent { return _owner; }
		public function set owner(value:ITriggerComponent):void
		{
			_owner=value;
		}
		
		protected var _label : String
		public function get label():String { return _label; }
		public function set label(value:String):void
		{
			_label=value;
		}
		
		protected var _type : ActionType = ActionType.ONETIME;
		public function get type():ActionType{ return _type; }

		public function get isDestroyed():Boolean{ return _destroyed; }
		public function get isStopped():Boolean{ return _stoped; }
	}
}