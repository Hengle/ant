#include <ozz/base/platform.h>
#include <ozz/base/maths/simd_math.h>

namespace ozz {
	namespace animation {
		class Skeleton;
	}
}

struct hierarchy_build_data {
	ozz::animation::Skeleton *skeleton;
};

struct animation_result {
	ozz::Range<ozz::math::Float4x4>	joints;
};