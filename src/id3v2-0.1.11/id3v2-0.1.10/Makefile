all: id3v2

VERSION=0.1.10

PREFIX=	/usr/local
CXXFLAGS+=	-I${PREFIX}/include/ -DVERSION="\"${VERSION}\"" #-DSORT_RUNTIME
LDFLAGS+=	-L${PREFIX}/lib/ 

id3v2:	convert.o list.o id3v2.o genre.o
	c++ ${LDFLAGS} -pedantic -Wall -lz -lid3 -g -o $@ $^

create_map: create_map.o
	c++ -Wall -g -o $@ $^

install: all
	install -c -s id3v2 ${PREFIX}/bin/id3v2
	nroff -man id3v2.1 > ${PREFIX}/man/man1/id3v2.1

clean:
	rm -f id3v2 create_map core *.o

tarball:
	ln -s . id3v2-${VERSION}
	tar zhcf id3v2-${VERSION}.tar.gz  \
		--exclude=CVS --exclude-from .cvsignore \
		--exclude=id3v2-${VERSION}/id3v2-${VERSION} \
		id3v2-${VERSION}
	rm id3v2-${VERSION}
	
