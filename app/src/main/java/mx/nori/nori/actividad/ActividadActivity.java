package mx.nori.nori.actividad;

import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

import im.delight.android.location.SimpleLocation;
import mx.nori.nori.Functions;
import mx.nori.nori.Impresora;
import mx.nori.nori.NoriSDK.Actividad;
import mx.nori.nori.NoriSDK.Causalidad;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.NoriSDK.Vendedor;
import mx.nori.nori.R;

public class ActividadActivity extends AppCompatActivity {
    private SimpleLocation location;

    private static Actividad actividad;
    private static Socio socio;
    TextView textViewID, textViewFecha, textViewSocio, textViewVendedor;
    Spinner spinnerTiposActividades, spinnerCausalidades;
    EditText editTextComentario, editTextNotas;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_actividad);

        int actividad_id = getIntent().getIntExtra("id", 0);
        int socio_id = getIntent().getIntExtra("socio_id", 0);

        location = new SimpleLocation(this);
        if (!location.hasLocationEnabled()) {
            SimpleLocation.openSettings(this);
        }

        actividad = new Actividad();
        socio = new Socio();

        textViewID = findViewById(R.id.textViewID);
        textViewFecha = findViewById(R.id.textViewFecha);
        textViewSocio = findViewById(R.id.textViewSocio);
        textViewVendedor = findViewById(R.id.textViewVendedor);

        spinnerTiposActividades = findViewById(R.id.spinnerTiposActividades);
        spinnerCausalidades = findViewById(R.id.spinnerCausalidades);

        editTextComentario = findViewById(R.id.editTextComentario);
        editTextNotas = findViewById(R.id.editTextNotas);

        if (actividad_id != 0) {
            actividad = Actividad.Obtener(actividad_id);
        }

        if (actividad.getSocio_id() == 0 && socio_id == 0) {
            socio = Socio.Obtener(Global.getUsuario().getSocio_id());
        } else {
            if (actividad.getSocio_id() != 0 && socio_id == 0) {
                socio = Socio.Obtener(actividad.getSocio_id());
            } else if (socio_id != 0) {
                socio = Socio.Obtener(socio_id);
            }
        }

        List<Actividad.Tipo> tipos_actividades = Actividad.Tipo.Listar();
        if (tipos_actividades != null) {
            ArrayAdapter<Actividad.Tipo> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, tipos_actividades);
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);

            spinnerTiposActividades.setAdapter(adapter);
        }

        List<Causalidad> causalidades = Causalidad.Listar();
        if (causalidades != null) {
            ArrayAdapter<Causalidad> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, causalidades);
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);

            spinnerCausalidades.setAdapter(adapter);
        }
        
        Cargar();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.documento, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.guardar:
                Guardar();
                return  true;
            case R.id.imprimir:
                if (actividad.getId() != 0) {
                    Impresora impresora = new Impresora();
                    impresora.ImprimirActividad(actividad);
                } else {
                    Toast.makeText(this, "La actividad aún no ha sido guardada.", Toast.LENGTH_SHORT).show();
                }
                return  true;
        }
        return super.onOptionsItemSelected(item);
    }

    private Boolean Cargar()
    {
        try
        {
            textViewID.setText(actividad.getId().toString());
            textViewFecha.setText(Functions.toDateTimeString(actividad.getFecha_creacion()));

            textViewSocio.setText(socio.getNombre());
            Vendedor vendedor = Vendedor.Obtener(actividad.getVendedor_id());
            if (vendedor != null) {
                textViewVendedor.setText(vendedor.getNombre());
            }
            
            editTextComentario.setText(actividad.getComentarios());
            editTextNotas.setText(actividad.getNotas());

            return  true;
        } catch (Exception ex) {
            Toast.makeText(this, ex.getMessage(), Toast.LENGTH_SHORT).show();
            return false;
        }
    }

    private Boolean Guardar() {
        try {
            if (actividad.getId() == 0) {

                actividad.setLatitud(location.getLatitude());
                actividad.setLongitud(location.getLongitude());
                actividad.setSocio_id(socio.getId());
                actividad.setTipo_actividad_id(((Actividad.Tipo) spinnerTiposActividades.getSelectedItem()).getId());
                actividad.setCausalidad_id(((Causalidad) spinnerCausalidades.getSelectedItem()).getId());
                actividad.setComentarios(editTextComentario.getText().toString());
                actividad.setNotas(editTextNotas.getText().toString());

                if (actividad.Agregar()) {
                    Toast.makeText(this, "Información guardada correctamente.", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(this, Global.getError().getMessage(), Toast.LENGTH_SHORT).show();
                }
            } else {
                Toast.makeText(this, "Ya ha sido guardado la actividad.", Toast.LENGTH_SHORT).show();
            }
            return true;
        } catch (Exception ex) {
            Toast.makeText(this, ex.getMessage(), Toast.LENGTH_SHORT).show();
            return  false;
        }
    }

    public static Actividad getActividad() {
        return actividad;
    }

    public static Socio getSocio() {
        return socio;
    }

    public static void setSocio(Socio socio) {
        ActividadActivity.socio = socio;
    }

    @Override
    protected void onResume() {
        super.onResume();
        location.beginUpdates();
    }

    @Override
    protected void onPause() {
        location.endUpdates();
        super.onPause();
    }
}