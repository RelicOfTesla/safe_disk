package sec_fs

import "io"
import "fs"

type ISecFile interface{
	fs.File
	io.Writer
	io.Seeker
	// TODO: more
}

//TODO:
//var _ ISecFile = (*SecFile)(nil)

type IDirWalker interface{
	// TODO: 
	
}

//TODO:
//var _ IDirWalker = (*SecRoot)(nil)

type ISecRoot interface{
	// TODO: 
	
}
//TODO:
//var _ ISecRoot = (*SecDirWalker)(nil)
