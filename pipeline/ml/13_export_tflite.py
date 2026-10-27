"""Export TFLite (float32, float16, int8 dinamico), confronto accuratezza e equivalenza con Keras.
Sceglie float16 se la perdita di top-1 sul test <= 1 punto rispetto a float32, altrimenti float32.
Output: data/model/model.tflite (+ model_{f32,f16,int8dyn}.tflite)"""
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow import keras

M = Path(__file__).resolve().parents[2] / "data" / "model"
model = keras.models.load_model(M / "model.keras")
z = np.load(M / "cache.npz"); X, y, split = z["X"], z["y"], z["split"]
te = split == "test"; Xt, yt = X[te].astype(np.float32), y[te]

def convert(kind):
    c = tf.lite.TFLiteConverter.from_keras_model(model)
    if kind == "f16":
        c.optimizations = [tf.lite.Optimize.DEFAULT]; c.target_spec.supported_types = [tf.float16]
    elif kind == "int8dyn":
        c.optimizations = [tf.lite.Optimize.DEFAULT]
    data = c.convert()
    (M / f"model_{kind}.tflite").write_bytes(data)
    return data

def run(data, imgs):
    it = tf.lite.Interpreter(model_content=data); it.allocate_tensors()
    i, o = it.get_input_details()[0], it.get_output_details()[0]
    out = []
    for a in imgs:
        it.set_tensor(i["index"], a[None]); it.invoke(); out.append(it.get_tensor(o["index"])[0])
    return np.array(out), i["shape"].tolist(), i["dtype"].__name__

ref = model.predict(Xt, batch_size=64, verbose=0)
rep = {"keras_top1": float((ref.argmax(1) == yt).mean())}
best = None
for kind in ("f32", "f16", "int8dyn"):
    d = convert(kind)
    sub = slice(0, len(Xt), 1)
    p, shp, dt = run(d, Xt)
    rep[kind] = {"bytes": len(d), "top1_test": float((p.argmax(1) == yt).mean()),
                 "max_abs_diff_vs_keras": float(np.abs(p - ref).max()), "agree_top1_vs_keras": float((p.argmax(1) == ref.argmax(1)).mean()),
                 "input": shp, "input_dtype": dt}
    print(kind, rep[kind], flush=True)
choice = "f16" if rep["f16"]["top1_test"] >= rep["f32"]["top1_test"] - 0.01 and rep["f16"]["agree_top1_vs_keras"] > 0.98 else "f32"
(M / "model.tflite").write_bytes((M / f"model_{choice}.tflite").read_bytes())
rep["scelto"] = choice
(M / "export_report.json").write_text(json.dumps(rep, indent=1))
print("scelto", choice)
