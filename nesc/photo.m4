output int Photo_read;
input  int Photo_readDone;

C do
int Photo_read () {
   return call Photo.read();
}
end
