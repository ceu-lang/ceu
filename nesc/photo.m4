output int Photo_read;
input  int Photo_readDone;

C {
static inline int Photo_read () {
   return call Photo.read();
}
};
