module driver

import os

fn test_the_object_cache_follows_v3cache_like_the_module_cache() {
	previous := os.getenv_opt('V3CACHE')
	defer {
		if value := previous {
			os.setenv('V3CACHE', value, true)
		} else {
			os.unsetenv('V3CACHE')
		}
	}
	shared := os.join_path(os.vtmp_dir(), 'v3cache_shared_${os.getpid()}')
	os.setenv('V3CACHE', shared, true)
	assert v3_thirdparty_objs_dir() == os.join_path(shared, 'v3_thirdparty_objs')
	os.unsetenv('V3CACHE')
	assert v3_thirdparty_objs_dir() == os.join_path(os.vtmp_dir(), 'v3_thirdparty_objs')
}
