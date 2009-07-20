package PBLabs.Components.StateMachine
{
   /**
    * State that enforces a delay (measured in ticks) before attempting
    * to transition.
    */
   public class DelayState extends BasicState
   {
      /**
       * Number of ticks to wait before switching state.
       * 
       * If this is 2, then on the second Tick() we will change state.
       */
      public var Delay:Number = 0;
      
      /**
       * Variance in duration of delay. Plus or minus.
       */
      public var Variance:Number = 0;
      
      /**
       * Number of ticks remaining.
       */
      public var DelayRemaining:int = 0;
            
      public override function Enter(fsm:IMachine):void
      {
         // Set the delay.
         DelayRemaining = Delay;
         
         if(Variance > 0)
            DelayRemaining += Math.round(2.0 * (Math.random() - 0.5) * Variance);
         
         // Pass control up.
         super.Enter(fsm);
      }
      
      public override function Tick(fsm:IMachine):void
      {
         // Tick the delay.
         //trace("Ticking delay state!");
         DelayRemaining--;
         if(DelayRemaining > 0)
            return;
            
         // Pass control upwards.
         super.Tick(fsm);   
      }
   }
}