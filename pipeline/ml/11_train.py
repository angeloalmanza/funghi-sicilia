"""Fine-tuning EfficientNetB0 (ImageNet) su 113 classi. Input 224x224 RGB 0-255 (normalizzazione dentro il modello).
Fase 1: solo testa; fase 2: sblocca la rete (BatchNorm congelate). Salva data/model/model.keras + probabilità val/test."""
import json
import time
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

M = Path(__file__).resolve().parents[2] / "data" / "model"
tf.random.set_seed(42); np.random.seed(42)
z = np.load(M / "cache.npz")
X, y, w, split = z["X"], z["y"], z["w"], z["split"]
NC = int(y.max()) + 1
tr, va, te = (split == "train"), (split == "val"), (split == "test")

cnt = np.bincount(y[tr], minlength=NC).astype(float)
cw = np.clip((np.median(cnt[cnt > 0]) / np.maximum(cnt, 1)) ** 0.5, 0.3, 3.0)
sw = (cw[y] * w).astype(np.float32)

aug = keras.Sequential([
    layers.RandomFlip("horizontal"), layers.RandomRotation(0.08), layers.RandomZoom((-0.25, 0.1)),
    layers.RandomTranslation(0.1, 0.1), layers.RandomBrightness(0.2, value_range=(0, 255)),
    layers.RandomContrast(0.2),
])
def ds(mask, train, bs=32):
    d = tf.data.Dataset.from_tensor_slices((X[mask], keras.utils.to_categorical(y[mask], NC), sw[mask]))
    if train:
        d = d.shuffle(4000, seed=1).batch(bs).map(lambda a, b, c: (tf.clip_by_value(aug(tf.cast(a, tf.float32), training=True), 0, 255), b, c))
    else:
        d = d.batch(bs).map(lambda a, b, c: (tf.cast(a, tf.float32), b, c))
    return d.prefetch(2)

base = keras.applications.EfficientNetB0(include_top=False, weights="imagenet", input_shape=(224, 224, 3), pooling="avg")
inp = keras.Input((224, 224, 3))
x = base(inp, training=False)
x = layers.Dropout(0.3)(x)
out = layers.Dense(NC, activation="softmax", name="probs")(x)
model = keras.Model(inp, out)
loss = keras.losses.CategoricalCrossentropy(label_smoothing=0.1)

def fit(lr, epochs, patience, tag):
    model.compile(keras.optimizers.Adam(lr), loss=loss, metrics=["accuracy", keras.metrics.TopKCategoricalAccuracy(5, name="top5")])
    cb = [keras.callbacks.EarlyStopping("val_loss", patience=patience, restore_best_weights=True),
          keras.callbacks.ReduceLROnPlateau("val_loss", factor=0.4, patience=2, min_lr=1e-6)]
    t = time.time()
    h = model.fit(ds(tr, True), validation_data=ds(va, False), epochs=epochs, callbacks=cb, verbose=2)
    print(f"[{tag}] {time.time()-t:.0f}s val_acc={max(h.history['val_accuracy']):.3f}", flush=True)

base.trainable = False
fit(1e-3, 8, 3, "fase1")
base.trainable = True
for l in base.layers:
    if isinstance(l, layers.BatchNormalization):
        l.trainable = False
fit(1e-4, 14, 4, "fase2")

model.save(M / "model.keras")
for name, m in (("val", va), ("test", te)):
    p = model.predict(X[m].astype(np.float32), batch_size=64, verbose=0)
    np.savez(M / f"probs_{name}.npz", p=p, y=y[m])
    print(name, "top1", (p.argmax(1) == y[m]).mean(), flush=True)
print("FINE")
