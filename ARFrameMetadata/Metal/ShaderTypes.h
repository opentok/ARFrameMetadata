//
//  ShaderTypes.h
//  ARFrameMetadata
//
//  Created by Jerónimo Valli on 9/22/20.
//  Copyright © 2020 tokbox. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

struct Vertex {
    vector_float4 color;
    vector_float2 pos;
};

#endif /* ShaderTypes_h */
