import { VIEW, MOVEMENT, LEVEL, ANIMATION } from './config.js';

const overlay = document.getElementById('overlay');
const title = document.getElementById('overlay-title');
const kicker = document.getElementById('overlay-kicker');
const copy = document.getElementById('overlay-copy');
const hint = document.getElementById('overlay-hint');
const button = document.getElementById('overlay-button');
let currentScene;
let mode = 'playing';

function showOverlay(kind) {
  mode = kind;
  const complete = kind === 'complete';
  kicker.textContent = complete ? 'A MOMENT OF PEACE' : 'TAKE A BREATH';
  title.textContent = complete ? 'Forest path complete' : 'Paused';
  copy.textContent = complete ? 'You found your way to the light.' : 'The forest will be here when you return.';
  button.innerHTML = complete ? 'Walk again <span>→</span>' : 'Continue journey <span>→</span>';
  hint.textContent = complete ? 'Press R to restart' : 'Press Esc to resume';
  overlay.classList.remove('hidden');
  currentScene.scene.pause();
  button.focus();
}

function resume() {
  if (mode !== 'paused') return;
  overlay.classList.add('hidden');
  mode = 'playing';
  currentScene.input.keyboard.resetKeys();
  currentScene.scene.resume();
  document.activeElement.blur();
}

function restart() {
  if (!currentScene) return;
  overlay.classList.add('hidden');
  mode = 'playing';
  currentScene.scene.resume();
  currentScene.scene.restart();
  document.activeElement.blur();
}

button.addEventListener('click', () => mode === 'complete' ? restart() : resume());
window.addEventListener('keydown', event => {
  if (event.repeat || !currentScene) return;
  if (event.code === 'Escape') {
    event.preventDefault();
    if (mode === 'playing') showOverlay('paused');
    else if (mode === 'paused') resume();
  } else if (event.code === 'KeyR') {
    event.preventDefault();
    restart();
  }
});
window.addEventListener('blur', () => {
  if (currentScene && currentScene.input.keyboard) currentScene.input.keyboard.resetKeys();
});

class Forest extends Phaser.Scene {
  constructor() { super('forest'); }

  preload() {
    this.load.image('background', 'assets/forest-background.png');
    this.load.image('middle', 'assets/forest-middle.png');
    this.load.image('foliage', 'assets/forest-foreground.png');
    this.load.image('ground', 'assets/ground.png');
    this.load.image('log', 'assets/log.png');
    this.load.image('rocks', 'assets/rocks.png');
    this.load.image('root', 'assets/root.png');
    this.load.image('tree', 'assets/banyan.png');
    this.load.spritesheet('prince', 'assets/prince-frames.png', { frameWidth: 160, frameHeight: 160 });
    this.load.on('loaderror', file => { document.getElementById('loading').textContent = `Could not load ${file.key}. Please restart the local server.`; });
  }

  create() {
    currentScene = this;
    document.getElementById('loading').classList.add('hidden');
    this.physics.world.setBounds(0, 0, VIEW.worldWidth, VIEW.groundY + 160);
    this.cameras.main.setBounds(0, 0, VIEW.worldWidth, VIEW.height);
    this.add.image(0, 0, 'background').setOrigin(0).setDisplaySize(2280, 720).setScrollFactor(.36, 1).setDepth(-20);
    this.add.image(0, 25, 'middle').setOrigin(0).setDisplaySize(2900, 565).setScrollFactor(.6, 1).setAlpha(.2).setDepth(-15);
    this.add.image(0, 0, 'foliage').setOrigin(0).setDisplaySize(2850, 500).setScrollFactor(.58, 1).setAlpha(.3).setDepth(-10);
    const ground = this.add.tileSprite(0, VIEW.groundY - 2, VIEW.worldWidth, 150, 'ground').setOrigin(0).setDepth(-2);
    ground.tileScaleX = .45;
    ground.tileScaleY = .45;
    const floor = this.add.zone(VIEW.worldWidth / 2, VIEW.groundY + 70, VIEW.worldWidth, 140);
    this.physics.add.existing(floor, true);
    this.platforms = this.physics.add.staticGroup();
    for (const obstacle of LEVEL.obstacles) {
      this.add.image(obstacle.x, VIEW.groundY + 4, obstacle.type).setOrigin(.5, 1).setDisplaySize(obstacle.width + 20, obstacle.height + 12).setDepth(1);
      const zone = this.add.zone(obstacle.x, VIEW.groundY - obstacle.height / 2, obstacle.width, obstacle.height);
      this.physics.add.existing(zone, true);
      this.platforms.add(zone);
    }
    this.add.image(LEVEL.goalX + 30, VIEW.groundY + 8, 'tree').setOrigin(.5, 1).setDisplaySize(400, 400).setDepth(0);
    this.add.ellipse(LEVEL.goalX, VIEW.groundY - 12, 190, 45, 0xf8d982, .11).setBlendMode(Phaser.BlendModes.ADD);
    for (let i = 0; i < 9; i++) {
      const mist = this.add.ellipse(i * 500 + 80, 530 + (i % 2) * 24, 340, 40, 0xa4ead7, .025).setDepth(-1);
      this.tweens.add({ targets: mist, x: mist.x + 70, alpha: .055, duration: 5500 + i * 350, yoyo: true, repeat: -1 });
    }
    for (let i = 0; i < 30; i++) {
      const x = 150 + ((i * 431) % (VIEW.worldWidth - 300));
      const y = 100 + ((i * 137) % 400);
      const firefly = this.add.circle(x, y, i % 3 === 0 ? 2.7 : 1.7, 0xd9f5ad, .35).setBlendMode(Phaser.BlendModes.ADD).setDepth(3);
      this.tweens.add({ targets: firefly, alpha: .8, y: y - 24, duration: 1800 + (i % 5) * 400, yoyo: true, repeat: -1, delay: i * 90 });
    }
    for (const [name, frames] of Object.entries(ANIMATION)) {
      if (!this.anims.exists(name)) this.anims.create({ key: name, frames: frames.map(frame => ({ key: 'prince', frame })), frameRate: name === 'run' ? 9 : name === 'idle' ? 3 : 8, repeat: name === 'idle' || name === 'run' ? -1 : 0 });
    }
    this.player = this.physics.add.sprite(LEVEL.startX, VIEW.groundY + 8, 'prince').setOrigin(.5, 1).setDepth(2);
    this.player.body.setSize(44, 122).setOffset(58, 30);
    this.player.setCollideWorldBounds(true).setMaxVelocity(MOVEMENT.speed, 1000).setDragX(MOVEMENT.drag);
    this.physics.add.collider(this.player, floor);
    this.physics.add.collider(this.player, this.platforms);
    this.cameras.main.startFollow(this.player, false, .08, .08, -220, 0);
    this.keys = this.input.keyboard.addKeys({ left: 'LEFT', right: 'RIGHT', a: 'A', d: 'D', jump: 'SPACE' });
    this.lastGrounded = -Infinity;
    this.jumpPressed = -Infinity;
    this.wasGrounded = false;
    this.landingUntil = 0;
  }

  update(time) {
    const player = this.player;
    const body = player.body;
    const grounded = body.blocked.down || body.touching.down;
    if (grounded) this.lastGrounded = time;
    if (grounded && !this.wasGrounded && body.velocity.y >= 0) this.landingUntil = time + 180;
    this.wasGrounded = grounded;
    const left = this.keys.left.isDown || this.keys.a.isDown;
    const right = this.keys.right.isDown || this.keys.d.isDown;
    const direction = Number(right) - Number(left);
    player.setAccelerationX(direction * MOVEMENT.acceleration);
    if (direction) player.setFlipX(direction < 0);
    if (Phaser.Input.Keyboard.JustDown(this.keys.jump)) this.jumpPressed = time;
    if (time - this.jumpPressed <= MOVEMENT.bufferMs && time - this.lastGrounded <= MOVEMENT.coyoteMs) {
      player.setVelocityY(MOVEMENT.jumpVelocity);
      this.lastGrounded = -Infinity;
      this.jumpPressed = -Infinity;
      this.wasGrounded = false;
      this.landingUntil = 0;
    }
    if (Phaser.Input.Keyboard.JustUp(this.keys.jump) && body.velocity.y < -260) player.setVelocityY(-260);
    const inAir = !grounded || body.velocity.y < -50;
    const anim = inAir ? (body.velocity.y < 0 ? 'rise' : 'fall') : time < this.landingUntil ? 'land' : Math.abs(body.velocity.x) > 15 ? 'run' : 'idle';
    player.anims.play(anim, true);
    if (player.x >= LEVEL.goalX - 40 && mode === 'playing') showOverlay('complete');
  }
}

window.forestGame = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: VIEW.width,
  height: VIEW.height,
  backgroundColor: '#0a2027',
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  physics: { default: 'arcade', arcade: { gravity: { y: MOVEMENT.gravity }, debug: false } },
  scene: Forest
});
