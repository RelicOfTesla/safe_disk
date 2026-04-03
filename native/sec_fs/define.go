package sec_fs

import "io"

type ISecFile interface{
	io.ReadWriteSeeker
	io.Closer
	// TODO: more
}

//var _ ISecFile = (*SecFile)(nil)

type IDirWalker interface{
	// TODO: 
	
}

//var _ IDirWalker = (*SecRoot)(nil)

type ISecRoot interface{
	// TODO: 
	
}

//var _ ISecRoot = (*SecDirWalker)(nil)
