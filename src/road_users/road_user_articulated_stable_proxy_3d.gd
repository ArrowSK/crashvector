# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserArticulatedStableProxy3D
extends RoadUserArticulatedProxy3D

# Production wrapper for the established M15 articulated target. The topology,
# joints, masses, road collision and replay API are unchanged. Godot's contact
# manifold is now the sole source of impact momentum, preventing the historical
# probe-transfer path from launching pedestrians or bicycles.
