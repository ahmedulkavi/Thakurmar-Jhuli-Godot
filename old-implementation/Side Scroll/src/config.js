export const VIEW = { width: 1280, height: 720, worldWidth: 3840, groundY: 586 };
export const MOVEMENT = { speed: 300, acceleration: 2000, drag: 2400, gravity: 1800, jumpVelocity: -720, coyoteMs: 100, bufferMs: 120 };
export const LEVEL = {
  startX: 170,
  goalX: 3550,
  obstacles: [
    { type: 'log', x: 910, width: 140, height: 62 },
    { type: 'rocks', x: 1810, width: 120, height: 82 },
    { type: 'root', x: 2650, width: 140, height: 96 }
  ]
};
export const ANIMATION = { idle: [0,1,2,3], run: [4,5,6,7,8,9], rise: [10], fall: [11], land: [12,13] };
