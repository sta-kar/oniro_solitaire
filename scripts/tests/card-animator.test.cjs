// Run with Node and the SDK's TypeScript module path; no device or npm install.
const { readFileSync } = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const compilerPath = process.argv[2];
if (!compilerPath) {
  throw new Error('Usage: node scripts/tests/card-animator.test.cjs <SDK typescript.js>');
}
const ts = require(path.resolve(compilerPath));
const source = readFileSync(path.join(__dirname,
  '../../entry/src/main/ets/animation/CardAnimator.ets'), 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const dealModule = { exports: {} };
const dealSource = readFileSync(path.join(__dirname,
  '../../entry/src/main/ets/model/NewGameAnimation.ets'), 'utf8');
vm.runInNewContext(ts.transpileModule(dealSource, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, { module: dealModule, exports: dealModule.exports });
const { dealFlightFraction, dealSqueezeFraction } = dealModule.exports;
const handoffSource = readFileSync(path.join(__dirname,
  '../../entry/src/main/ets/animation/CardArtworkHandoff.ets'), 'utf8');
const compiledHandoff = ts.transpileModule(handoffSource, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;

function artworkFixture() {
  let nextTimer = 0;
  const timers = new Map();
  const frames = [];
  const warnings = [];
  const module = { exports: {} };
  vm.runInNewContext(compiledHandoff, {
    module, exports: module.exports,
    require: () => ({ FrameCallback: class {} }),
    setTimeout: (action) => {
      timers.set(++nextTimer, action);
      return nextTimer;
    },
    clearTimeout: (id) => timers.delete(id),
    console: { warn: (message) => warnings.push(message) }
  });
  const context = {
    postFrameCallback: (frame) => frames.push(frame)
  };
  return { handoff: new module.exports.CardArtworkHandoff(), context, frames, timers, warnings };
}

test('handoff waits for every destination side and a frame, including early decodes', () => {
  const { handoff, context, frames, timers } = artworkFixture();
  const movedCard = { id: 1, faceUp: true };
  const revealedCard = { id: 2, faceUp: true };
  let completions = 0;
  handoff.expect([movedCard, revealedCard]);
  handoff.decoded(context, movedCard);
  handoff.finish(context, () => completions++);
  handoff.decoded(context, { id: revealedCard.id, faceUp: false });
  assert.equal(frames.length, 0);
  handoff.decoded(context, revealedCard);
  handoff.decoded(context, revealedCard);
  assert.equal(frames.length, 1);
  assert.equal(completions, 0);
  frames[0].onIdle(0);
  frames[0].onIdle(0);
  assert.equal(completions, 1);
  assert.equal(timers.size, 0);
});

test('a cancelled handoff cannot finish the next transition and missing images time out', () => {
  const { handoff, context, frames, timers, warnings } = artworkFixture();
  const card = { id: 1, faceUp: true };
  let completions = 0;
  handoff.expect([card]);
  handoff.finish(context, () => assert.fail('cancelled handoff completed'));
  handoff.decoded(context, card);
  const staleFrame = frames[0];
  const [staleTimer] = timers.values();
  handoff.cancel();
  handoff.expect([card]);
  handoff.finish(context, () => completions++);
  staleFrame.onIdle(0);
  staleTimer();
  assert.equal(completions, 0);
  assert.equal(warnings.length, 0);
  const [activeTimer] = timers.values();
  activeTimer();
  assert.equal(completions, 1);
  assert.equal(warnings.length, 1);
  assert.equal(timers.size, 0);
});

function fixture() {
  let nextTimer = 0;
  const timers = new Map();
  const delays = [];
  const module = { exports: {} };
  vm.runInNewContext(compiled, {
    module, exports: module.exports,
    setTimeout: (action, delay) => {
      delays.push(delay);
      timers.set(++nextTimer, action);
      return nextTimer;
    },
    clearTimeout: (id) => timers.delete(id)
  });
  const animations = [];
  const context = {
    createAnimator: (options) => {
      const animation = {
        options, onFrame: () => {}, onFinish: () => {}, play: () => {},
        // Stress cancellation's documented final-frame behavior and reentrancy.
        cancel() { this.onFrame(1); this.onFinish(); }
      };
      animations.push(animation);
      return animation;
    }
  };
  return {
    owner: new module.exports.CardAnimator(), context, animations, timers, delays,
    flush() {
      const callbacks = [...timers.values()];
      timers.clear();
      callbacks.forEach((action) => action());
    }
  };
}

test('preserves the configured move and launch durations', () => {
  const f = fixture();
  f.owner.after(48, () => {});
  f.owner.play(f.context, 80, (t) => t, () => {});
  assert.equal(f.animations[0].options.duration, 80);
  assert.deepEqual(f.delays, [48]);
});

test('landing retains full width and the same animator before the squeeze begins', () => {
  const f = fixture();
  const frames = [];
  f.owner.play(f.context, 320, (t) => t, (progress) => {
    const flight = dealFlightFraction(progress, 240, 80);
    const squeeze = dealSqueezeFraction(progress, 240, 80);
    frames.push({ flight, width: Math.cos(Math.PI * squeeze / 2) });
  });
  const animation = f.animations[0];
  animation.onFrame(0.74);
  animation.onFrame(0.75); // 240 ms landing in the 320 ms arrival timeline.
  animation.onFrame(0.750001);
  assert.equal(f.animations.length, 1);
  assert.equal(f.timers.size, 0);
  assert.equal(animation.options.duration, 320);
  assert.equal(frames[1].width, 1);
  assert.deepEqual(frames[2], { flight: 1, width: 1 });
  assert.equal(frames[3].flight, 1);
  assert.ok(frames[3].width > 0.999999 && frames[3].width <= 1);
  animation.onFrame(1);
  assert.equal(frames.at(-1).flight, 1);
  assert.ok(Math.abs(frames.at(-1).width) < 1e-12);
});

test('covered deal cards land without squeezing and phase sampling clamps endpoints', () => {
  assert.equal(dealFlightFraction(1, 240, 0), 1);
  assert.equal(dealSqueezeFraction(1, 240, 0), 0);
  assert.equal(dealFlightFraction(-0.1, 240, 80), 0);
  assert.equal(dealSqueezeFraction(-0.1, 240, 80), 0);
  assert.equal(dealFlightFraction(1.1, 240, 80), 1);
  assert.equal(dealSqueezeFraction(1.1, 240, 80), 1);
});

test('completion commits the endpoint before advancing, exactly once', () => {
  const f = fixture();
  const events = [];
  f.owner.play(f.context, 80, (t) => t * t,
    (progress) => events.push(progress), () => events.push('finished'));
  const animation = f.animations[0];
  const finish = animation.onFinish;
  animation.onFrame(0.5);
  finish();
  finish();
  assert.deepEqual(events, [0, 0.25, 1, 'finished']);
});

test('teardown rejects queued launches and cancellation-generated frames', () => {
  const f = fixture();
  const events = [];
  f.owner.after(40, () => events.push('launch'));
  const queued = [...f.timers.values()][0];
  f.owner.play(f.context, 80, (t) => t,
    (progress) => events.push(progress), () => events.push('finished'));
  const staleFrame = f.animations[0].onFrame;
  const staleFinish = f.animations[0].onFinish;
  f.owner.cancel();
  queued();
  staleFrame(0.9);
  staleFinish();
  assert.equal(f.timers.size, 0);
  assert.deepEqual(events, [0]);
});

test('replaced motion cannot alter or finish its successor', () => {
  const f = fixture();
  const events = [];
  f.owner.play(f.context, 80, (t) => t, () => {}, () => events.push('old'));
  const staleFrame = f.animations[0].onFrame;
  const staleFinish = f.animations[0].onFinish;
  f.owner.play(f.context, 40, (t) => t,
    (progress) => events.push(progress), () => events.push('new'));
  staleFrame(1);
  staleFinish();
  f.animations[1].onFrame(0.5);
  f.animations[1].onFinish();
  assert.deepEqual(events, [0, 0.5, 1, 'new']);
});

test('zero-length motion stays asynchronous and can be cancelled or replaced', () => {
  const f = fixture();
  const events = [];
  f.owner.play(f.context, 0, (t) => t,
    (progress) => events.push(progress), () => events.push('zero'));
  assert.deepEqual(events, []);
  f.owner.cancel();
  f.flush();
  f.owner.play(f.context, 0, (t) => t,
    (progress) => events.push(progress), () => events.push('zero'));
  f.owner.play(f.context, 80, (t) => t,
    (progress) => events.push(progress), () => events.push('normal'));
  f.flush();
  f.animations[0].onFinish();
  assert.deepEqual(events, [0, 1, 'normal']);
});

test('completion can start another motion without old cleanup cancelling it', () => {
  const f = fixture();
  const events = [];
  f.owner.play(f.context, 40, (t) => t, () => {}, () => {
    f.owner.play(f.context, 40, (t) => t,
      (progress) => events.push(progress), () => events.push('second'));
  });
  const finishFirst = f.animations[0].onFinish;
  finishFirst();
  finishFirst();
  f.animations[1].onFrame(0.5);
  f.animations[1].onFinish();
  assert.deepEqual(events, [0, 0.5, 1, 'second']);
});

test('removing an overlay between halves prevents the deferred second half', () => {
  const f = fixture();
  const events = [];
  f.owner.play(f.context, 40, (t) => t, () => {}, () => {
    events.push('midpoint');
    f.owner.after(0, () => events.push('second-half'));
  });
  f.animations[0].onFinish();
  f.owner.cancel();
  f.flush();
  assert.deepEqual(events, ['midpoint']);
});
