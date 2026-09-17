window.beckonEntrance = function(id) {
  const tl = gsap.timeline({paused:true});
  const s = '[data-composition-id="'+id+'"] ';
  tl.from(s+'.role',{x:-16,opacity:0,duration:.3,ease:'sine.out'},.1);
  tl.from(s+'.headline',{y:24,opacity:0,duration:.4,ease:'power3.out'},.16);
  tl.from(s+'.support',{y:16,opacity:0,duration:.4,ease:'power2.out'},.3);
  tl.from(s+'.phone',{y:20,opacity:0,duration:.5,ease:'power2.out'},.1);
  window.__timelines = window.__timelines || {};
  window.__timelines[id] = tl;
  return tl;
};
