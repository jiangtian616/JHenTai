/// v7.7.7
int compareVersion(String a, String b) {
  List<String> numberA = a.replaceFirst('v', '').split('.');
  List<String> numberB = b.replaceFirst('v', '').split('.');
  
  if(numberA.length != numberB.length) {
    return 0;
  }
  
  for (int i = 0; i < numberA.length; i++) {
    int a = int.parse(numberA[i]);
    int b = int.parse(numberB[i]);
    if (a > b) {
      return 1;
    } else if (a < b) {
      return -1;
    }
  }
  
  return 0;
}
