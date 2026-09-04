# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m14.gd"

# M15 deliberately keeps the proven M14 production/editor layer intact and
# upgrades the shared RoadUserRigidProxy3D implementation underneath it.
# Pedestrians are now lightweight articulated rigid-body chains and bicycles
# have independently simulated wheel bodies joined to the rigid frame.
