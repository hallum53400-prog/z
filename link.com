<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Stickman Driver</title>
<style>
  body { margin:0; background:#222; display:flex; flex-direction:column; align-items:center; font-family:sans-serif; color:#fff; }
  canvas { background:#7ec8e3; border:3px solid #fff; margin-top:10px; }
  #info { margin:8px; font-size:18px; }
</style>
</head>
<body>
<div id="info">Score: 0 | Lives: 3</div>
<canvas id="c" width="480" height="600"></canvas>
<p>Arrow keys: drive · Space: brake · Dodge red boxes, grab yellow coins</p>

<script>
const canvas = document.getElementById("c");
const ctx = canvas.getContext("2d");
const info = document.getElementById("info");

const keys = {};
addEventListener("keydown", e => { keys[e.key] = true; if (e.key.startsWith("Arrow")||e.key===" ") e.preventDefault(); });
addEventListener("keyup", e => keys[e.key] = false);

const car = { x: 240, y: 520, w: 50, h: 70, speed: 0 };
let objects = [];
let score = 0, lives = 3, roadOffset = 0, gameOver = false, spawnTimer = 0;

function spawn() {
  const type = Math.random() < 0.7 ? "box" : "coin";
  const x = 80 + Math.random() * 320;
  objects.push({ type, x, y: -40, w: type === "box" ? 50 : 24, h: type === "box" ? 50 : 24 });
}

function drawStickman(x, y) {
  ctx.strokeStyle = "#000"; ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(x, y - 30, 10, 0, Math.PI * 2);
  ctx.moveTo(x, y - 20); ctx.lineTo(x, y + 5);      // body
  ctx.moveTo(x, y - 15); ctx.lineTo(x + 12, y - 5); // arm
  ctx.moveTo(x, y - 15); ctx.lineTo(x - 6, y - 5);
  ctx.moveTo(x, y + 5);  ctx.lineTo(x + 8, y + 15); // legs
  ctx.moveTo(x, y + 5);  ctx.lineTo(x - 8, y + 15);
  ctx.stroke();
}

function drawCar() {
  ctx.fillStyle = "#e74c3c";
  ctx.fillRect(car.x - car.w/2, car.y - car.h/2, car.w, car.h);
  ctx.fillStyle = "#222";
  ctx.fillRect(car.x - car.w/2 - 4, car.y - 25, 6, 14);
  ctx.fillRect(car.x + car.w/2 - 2, car.y - 25, 6, 14);
  ctx.fillRect(car.x - car.w/2 - 4, car.y + 12, 6, 14);
  ctx.fillRect(car.x + car.w/2 - 2, car.y + 12, 6, 14);
  ctx.fillStyle = "#aee";
  ctx.fillRect(car.x - 18, car.y - 22, 36, 14);
  drawStickman(car.x, car.y + 2);
}

function update() {
  if (gameOver) return;

  if (keys["ArrowUp"]) car.speed = Math.min(car.speed + 0.15, 8);
  else if (keys[" "]) car.speed = Math.max(car.speed - 0.4, 0);
  else car.speed = Math.max(car.speed - 0.05, 0);

  if (keys["ArrowLeft"]) car.x -= 4;
  if (keys["ArrowRight"]) car.x += 4;
  car.x = Math.max(90, Math.min(390, car.x));

  roadOffset = (roadOffset + 4 + car.speed) % 40;

  spawnTimer++;
  if (spawnTimer > Math.max(25, 60 - score / 5)) { spawn(); spawnTimer = 0; }

  for (const o of objects) o.y += 3 + car.speed * 0.5;
  objects = objects.filter(o => o.y < canvas.height + 60);

  for (const o of objects) {
    const hit = Math.abs(o.x - car.x) < (o.w + car.w) / 2 - 5 &&
                Math.abs(o.y - car.y) < (o.h + car.h) / 2 - 5;
    if (hit) {
      o.y = 9999;
      if (o.type === "coin") score += 10;
      else { lives--; car.speed = 0; if (lives <= 0) gameOver = true; }
    }
  }
  objects = objects.filter(o => o.y < 9000);
  if (!gameOver) score += 0.1;
  info.textContent = `Score: ${Math.floor(score)} | Lives: ${lives}`;
}

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#4a4a4a";
  ctx.fillRect(80, 0, 320, canvas.height);
  ctx.fillStyle = "#fff";
  for (let y = -40 + roadOffset; y < canvas.height; y += 40)
    ctx.fillRect(238, y, 4, 20);

  for (const o of objects) {
    if (o.type === "box") {
      ctx.fillStyle = "#c0392b";
      ctx.fillRect(o.x - o.w/2, o.y - o.h/2, o.w, o.h);
    } else {
      ctx.fillStyle = "#f1c40f";
      ctx.beginPath(); ctx.arc(o.x, o.y, o.w/2, 0, Math.PI*2); ctx.fill();
    }
  }
  drawCar();

  if (gameOver) {
    ctx.fillStyle = "rgba(0,0,0,0.6)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = "#fff";
    ctx.font = "bold 36px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("GAME OVER", canvas.width/2, canvas.height/2 - 10);
    ctx.font = "20px sans-serif";
    ctx.fillText("Refresh the page to play again", canvas.width/2, canvas.height/2 + 30);
  }
}

function loop() { update(); draw(); requestAnimationFrame(loop); }
loop();
</script>
</body>
</html>
