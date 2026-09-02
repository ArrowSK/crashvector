# Cinematic video export

CrashVector M7 renders video from an already-recorded replay. It does not re-run the crash while exporting. This keeps the exported frame sequence deterministic and prevents graphics performance from changing simulation timing.

## Workflow

1. Configure and run a scenario to completion.
2. Open **Cinematic Video**.
3. Select resolution, frame rate, camera preset, paint, slow motion, and overlay options.
4. Choose an `.mp4` output path.
5. CrashVector renders every frame to an offscreen viewport, then asks the locally installed FFmpeg executable to encode the JPEG sequence as H.264 MP4.

The temporary source frames are removed after a successful encode unless **Keep rendered JPEG frames** is enabled. If encoding fails, frames are retained so the render work is not lost.

## Visual profiles

Supported output sizes are 1920×1080, 2560×1440, and 3840×2160 at 30 or 60 fps.

Camera presets:

- **Auto cinematic** — tracking approach, impact close-up, then aftermath orbit.
- **Wide overview** — stable scene-wide composition.
- **Vehicle tracking** — follows the primary passenger car.
- **Impact close-up** — prioritizes the collision point.
- **Aftermath orbit** — moves around the post-impact vehicle pair.

Impact slow motion defaults to 0.25x around first contact. This is a presentation retime only; recorded physics states are never recalculated at the slower rate.

## Educational overlays

The exported video can include an opening scenario title, live primary-vehicle speed and front-crush readout, a CrashVector educational-simulation watermark, and a closing card with delta-v, peak simulated deceleration, maximum front crush, safety-cell deformation proxy, and initial kinetic energy.

Every successful export also writes `<video-name>.crashvector-video.json`. The sidecar records the scenario, export profile, key analysis values, frame count, output duration, first-contact time, and the educational-use disclaimer.

## FFmpeg

CrashVector does not bundle FFmpeg. M7 looks for a system installation and invokes it as an external process. The generated command uses H.264 (`libx264`), CRF 18, `yuv420p`, and MP4 fast-start metadata for broad playback compatibility.

Keeping FFmpeg external avoids silently redistributing codec binaries under terms that may differ from CrashVector's MPL-2.0 source licence. Packaging a known FFmpeg build can be revisited for a future desktop release with the corresponding licence notices and build configuration documented explicitly.

## Scope

Exported metrics remain outputs of CrashVector's educational simulation. A polished video does not make the structural model a certified accident reconstruction, manufacturer-specific crash prediction, homologation result, or occupant injury assessment.
