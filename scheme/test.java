
import java.nio.file.Paths;

public class test {
	public static void main(String[] args) {
		System.out.println("hello from java!");
		String pwd = Paths.get(".").toAbsolutePath().normalize().toString();
		KWorker.kmain(pwd);
	}
}
