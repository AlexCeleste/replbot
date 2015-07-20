
import twitter4j.TwitterException;

import java.lang.*;
import java.util.*;
import java.nio.file.Paths;

public class RBWorker {
	public static void main(String[] args) {
		try {
			String pwd = Paths.get(".").toAbsolutePath().normalize().toString();
			KWorker.kmain(pwd + "/scheme/app.scm");
		} catch (Exception e) {
			System.out.println(e.getMessage());
			System.exit(-1);
		}
	}
}

