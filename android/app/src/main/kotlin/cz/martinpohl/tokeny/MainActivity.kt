package cz.martinpohl.tokeny

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import cz.martinpohl.tokeny.ui.TokenyApp
import cz.martinpohl.tokeny.ui.TokenyPage
import cz.martinpohl.tokeny.ui.TokenyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT),
        )
        setContent {
            TokenyTheme {
                TokenyPage {
                    TokenyApp()
                }
            }
        }
    }
}
